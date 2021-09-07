read -p "请输入你的节点ID：" nodeid
docker rm soga${nodeid} -f ;
docker run --restart=on-failure --name soga${nodeid} -d \
-v /etc/soga/:/etc/soga/ --network host \
-e type=sspanel-uim \
-e server_type=v2ray \
-e api=webapi \
-e soga_key=KYWrnJF1HDYjAweM3AMqVkXZ8RGcm9CS \
-e webapi_url=https://panda.mba/ \
-e webapi_key=panda \
-e node_id=${nodeid} \
-e cert_domain=aaaa.com \
-e cert_mode=http \
sprov065/soga
