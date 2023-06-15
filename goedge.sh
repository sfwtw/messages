#!/bin/bash

if [ $# -ne 3 ]; then
    echo "Usage: $0 endpoints nodeId secret"
    exit 1
fi

endpoints="$1"
nodeId="$2"
secret="$3"

apt update -y && apt upgrade -y
apt install wget unzip libc6 -y
# 下载 edge-node 压缩包并解压到 /root/goedge 目录下
wget https://raw.githubusercontent.com/sfwtw/messages/master/edge-node-linux-amd64-community-v1.2.0.zip -O /tmp/edge-node.zip
unzip /tmp/edge-node.zip -d /tmp/
mv /tmp/edge-node /root/goedge

# 写入 api.yaml 配置文件
cat <<EOF > /root/goedge/configs/api.yaml
rpc:
  endpoints: [ "${endpoints}" ]
  nodeId: "${nodeId}"
  secret: "${secret}"
EOF

/root/goedge/bin/edge-node start
ps ax|grep edge-node
