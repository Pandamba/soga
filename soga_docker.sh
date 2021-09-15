#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "${red}未本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者${plain}\n"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_docker() {
    if [[ ! `command -v docker` ]]; then
        if [[ x"${release}" == x"centos" ]]; then
            yum install epel-release -y
            yum install wget curl unzip tar crontabs socat yum-utils -y
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install docker-ce docker-ce-cli containerd.io -y
            systemctl enable docker --now
        elif [[ x"${release}" == x"ubuntu" ]]; then
            apt-get update
            apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install docker-ce docker-ce-cli containerd.io -y
            systemctl enable docker --now
        elif [[ x"${release}" == x"debian" ]]; then
            apt-get update
            apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y
            curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
            apt-get update
            apt-get install docker-ce docker-ce-cli containerd.io -y
            systemctl enable docker --now
        fi
    fi
}

install_soga() {
    apidomain=$(awk -F[/:] '{print $4}' <<< ${apihost})
    soganame=${apidomain}_${nodetype}_${nodeid}
    docker ps | grep -wq "soga_${soganame}"
    if [[ $? -eq 0 ]]; then
        docker rm -f soga_${soganame}
    fi
    docker pull sprov065/soga:latest
    docker run --restart=on-failure --name soga -d -v /etc/soga/:/etc/soga/ --network host -e type=sspanel-uim -e server_type=${nodetype} -e api=webapi -e webapi_url=${apihost} -e webapi_key=${apikey} -e node_id=${nodeid} -e cert_domain=aaaa.com -e cert_mode=${certmode} -e soga_key=${sogakey} sprov065/soga:latest
    docker ps | grep -wq "soga_${soganame}"
    if [[ $? -eq 0 ]]; then
        crontab -l > /tmp/cronconf
        if grep -wq "soga_${soganame}" /tmp/cronconf;then
            sed -i "/soga_${soganame}/d" /tmp/cronconf
        fi
        echo "3 6 * * *  docker restart soga_${soganame}" >> /tmp/cronconf
        crontab /tmp/cronconf
        rm -f /tmp/cronconf
        echo -e "${green}定时任务设置成功！每天6点3分重启节点 ${nodeid} 服务${plain}"
        crontab -l | grep -w "soga_${soganame}"
        echo -e "${green}节点 ${nodeid} 安装成功！${plain}"
        echo -e "${green}如无法启动请先检查前端配置是否正确！${plain}"
        docker ps
    fi
}

hello(){
    echo ""
    echo -e "${yellow}soga Docker版一键安装脚本，支持节点多开${plain}"
    echo -e "${yellow}支持系统:  CentOS 7+, Debian8+, Ubuntu16+${plain}"
    echo ""
}

help(){
    hello
    echo "使用示例：bash $0 -w http://www.domain.com:80 -k apikey -i 10 -t V2ray -s asdasd"
    echo ""
    echo "  -h     显示帮助信息"
    echo "  -w     【必填】指定WebApi地址，例：http://www.domain.com:80"
    echo "  -k     【必填】指定WebApikey"
    echo "  -i     【必填】指定节点ID"
    echo "  -t     【选填】指定节点类型，默认为v2ray，可选：v2ray, trojan, ss, ssr"
    echo "  -s     【必填】指定soga_key"
    echo "目前仅支持上述参数设定，其他参数将保持默认，暂不支持tls模式"
    echo ""
}

apihost=www.domain.com
apikey=demokey
nodeid=demoid
certmode=http

# -w webApiHost
# -k webApiKey
# -i NodeID
# -t NodeType
# -m CertMode
# -d CertDomain
# -s soga_key
# -h help
if [[ $# -eq 0 ]];then
    help
    exit 1
fi
while getopts ":w:k:i:t:h" optname
do
    case "$optname" in
      "w")
        apihost=$OPTARG
        ;;
      "k")
        apikey=$OPTARG
        ;;
      "i")
        nodeid=$OPTARG
        ;;
      "t")
        nodetype=$OPTARG
        ;;
      "s")
        sogakey=$OPTARG
        ;;
      "h")
        help
        exit 0
        ;;
      ":")
        echo "$OPTARG 选项没有参数值"
        ;;
      "?")
        echo "$OPTARG 选项未知"
        ;;
      *)
        help
        exit 1
        ;;
    esac
done

if [[ x"${apihost}" == x"www.domain.com" ]]; then
    echo -e "${red}未输入 -w 选项，请重新运行${plain}"
    exit 1
elif [[ x"${apikey}" == x"demokey" ]]; then
    echo -e "${red}未输入 -k 选项，请重新运行${plain}"
    exit 1
elif [[ x"${nodeid}" == x"demoid" ]]; then
    echo -e "${red}未输入 -i 选项，请重新运行${plain}"
    exit 1
elif [[ x"${sogakey}" == x ]]; then
    echo -e "${red}未输入 -i 选项，请重新运行${plain}"
    exit 1
elif [[ x"${nodetype}" == x ]]; then
    echo -e "${red}未指定节点类型，将使用默认值：v2ray ${plain}"
    nodetype=v2ray
fi
if [[ ! "${nodeid}" =~ ^[0-9]+$ ]]; then   
    echo -e "${red}-i 选项参数值仅限数字格式，请输入正确的参数值并重新运行${plain}"
    exit 1
fi 

echo -e "${green}开始安装${plain}"
install_docker
install_soga
