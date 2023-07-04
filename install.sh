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

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
    arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
    arch="arm64-v8a"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="64"
    echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
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

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/XrayR.service ]]; then
        return 2
    fi
    temp=$(systemctl status XrayR | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_XrayR() {
    if [[ -e /usr/local/XrayR/ ]]; then
        rm /usr/local/XrayR/ -rf
    fi

    mkdir /usr/local/XrayR/ -p
	cd /usr/local/XrayR/

    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/XrayR-project/XrayR/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}检测 XrayR 版本失败，可能是超出 Github API 限制，请稍后再试，或手动指定 XrayR 版本安装${plain}"
            exit 1
        fi
        echo -e "检测到 XrayR 最新版本：${last_version}，开始安装"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip http://43.250.107.159/XrayR-linux-64.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 XrayR 失败，请确保你的服务器能够下载 Github 的文件${plain}"
            exit 1
        fi
    else
        if [[ $1 == v* ]]; then
            last_version=$1
	else
	    last_version="v"$1
	fi
        url="http://43.250.107.159/XrayR-linux-64.zip"
        echo -e "开始安装 XrayR ${last_version}"
        wget -q -N --no-check-certificate -O /usr/local/XrayR/XrayR-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}下载 XrayR ${last_version} 失败，请确保此版本存在${plain}"
            exit 1
        fi
    fi

    unzip XrayR-linux.zip
    rm XrayR-linux.zip -f
    chmod +x XrayR
    mkdir /etc/XrayR/ -p
    rm /etc/systemd/system/XrayR.service -f
    file="https://github.com/XrayR-project/XrayR-release/raw/master/XrayR.service"
    wget -q -N --no-check-certificate -O /etc/systemd/system/XrayR.service ${file}
    #cp -f XrayR.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop XrayR
    systemctl enable XrayR
    echo -e "${green}XrayR ${last_version}${plain} 安装完成，已设置开机自启"
    cp geoip.dat /etc/XrayR/
    cp geosite.dat /etc/XrayR/ 

    if [[ ! -f /etc/XrayR/config.yml ]]; then
        cp config.yml /etc/XrayR/
        echo -e ""
        echo -e "全新安装，请先参看教程：https://github.com/XrayR-project/XrayR，配置必要的内容"
    else
        systemctl start XrayR
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}XrayR 重启成功${plain}"
        else
            echo -e "${red}XrayR 可能启动失败，请稍后使用 XrayR log 查看日志信息，若无法启动，则可能更改了配置格式，请前往 wiki 查看：https://github.com/XrayR-project/XrayR/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/XrayR/dns.json ]]; then
        cp dns.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/route.json ]]; then
        cp route.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/custom_inbound.json ]]; then
        cp custom_inbound.json /etc/XrayR/
    fi
    if [[ ! -f /etc/XrayR/rulelist ]]; then
        cp rulelist /etc/XrayR/
    fi
    curl -o /usr/bin/XrayR -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/XrayR.sh
    chmod +x /usr/bin/XrayR
    ln -s /usr/bin/XrayR /usr/bin/xrayr # 小写兼容
    chmod +x /usr/bin/xrayr
    cd $cur_dir
    rm -f install.sh
	content=$(cat <<EOF
    Log:
      Level: warning # Log level: none, error, warning, info, debug 
      AccessPath: # /etc/XrayR/access.Log
      ErrorPath: # /etc/XrayR/error.log
    DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
    RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
    InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
    OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
    ConnectionConfig:
      Handshake: 4 # Handshake time limit, Second
      ConnIdle: 30 # Connection idle time limit, Second
      UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
      DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
      BufferSize: 64 # The internal cache size of each connection, kB
    Nodes:
      - PanelType: "SSpanel" # Panel type: SSpanel, NewV2board, PMpanel, Proxypanel, V2RaySocks
        ApiConfig:
          ApiHost: "https://www.directyun.com"
          ApiKey: "sfwtw123sfwtw123"
          NodeID: 1
          NodeType: V2ray # Node type: V2ray, Shadowsocks, Trojan, Shadowsocks-Plugin
          Timeout: 30 # Timeout for the api request
          EnableVless: true # Enable Vless for V2ray Type
          VlessFlow: "" # Only support vless
          SpeedLimit: 0 # Mbps, Local settings will replace remote settings, 0 means disable
          DeviceLimit: 0 # Local settings will replace remote settings, 0 means disable
          RuleListPath: # /etc/XrayR/rulelist Path to local rulelist file
        ControllerConfig:
          ListenIP: 0.0.0.0 # IP address you want to listen
          SendIP: 0.0.0.0 # IP address you want to send pacakage
          UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
          EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
          DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
          EnableProxyProtocol: false # Only works for WebSocket and TCP
          AutoSpeedLimitConfig:
            Limit: 0 # Warned speed. Set to 0 to disable AutoSpeedLimit (mbps)
            WarnTimes: 0 # After (WarnTimes) consecutive warnings, the user will be limited. Set to 0 to punish overspeed user immediately.
            LimitSpeed: 0 # The speedlimit of a limited user (unit: mbps)
            LimitDuration: 0 # How many minutes will the limiting last (unit: minute)
          GlobalDeviceLimitConfig:
            Enable: false # Enable the global device limit of a user
            RedisAddr: 127.0.0.1:6379 # The redis server address
            RedisPassword: YOUR PASSWORD # Redis password
            RedisDB: 0 # Redis DB
            Timeout: 5 # Timeout for redis request
            Expiry: 60 # Expiry time (second)
          EnableFallback: false # Only support for Trojan and Vless
          FallBackConfigs:  # Support multiple fallbacks
            - SNI: # TLS SNI(Server Name Indication), Empty for any
              Alpn: # Alpn, Empty for any
             Path: # HTTP PATH, Empty for any
              Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/features/fallback.html for details.
             ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
          EnableREALITY: true # Enable REALITY
          REALITYConfigs:
            Show: true # Show REALITY debug
            Dest: tms.dingtalk.com:443 # Required, Same as fallback
            ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for disable
            ServerNames: # Required, list of available serverNames for the client, * wildcard is not supported at the moment.
              - tms.dingtalk.com
            PrivateKey: 8AEOkX2SI66loVwd2mBBlmLPVIbN1kpegaWGSen9_mQ # Required, execute './xray x25519' to generate.
            MinClientVer: # Optional, minimum version of Xray client, format is x.y.z.
            MaxClientVer: # Optional, maximum version of Xray client, format is x.y.z.
            MaxTimeDiff: 0 # Optional, maximum allowed time difference, unit is in milliseconds.
            ShortIds: # Required, list of available shortIds for the client, can be used to differentiate between different clients.
              - ""
              - 0123456789abcdef
          CertConfig:
            CertMode: dns # Option about how to get certificate: none, file, http, tls, dns. Choose "none" will forcedly disable the tls config.
           CertDomain: "node1.test.com" # Domain to cert
            CertFile: /etc/XrayR/cert/node1.test.com.cert # Provided if the CertMode is file
            KeyFile: /etc/XrayR/cert/node1.test.com.key
            Provider: alidns # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
            Email: test@me.com
            DNSEnv: # DNS ENV option used by DNS provider
              ALICLOUD_ACCESS_KEY: aaa
              ALICLOUD_SECRET_KEY: bbb
    EOF
    )

    echo "$content" > /etc/XrayR/config.yml
    echo -e ""
    echo "XrayR 管理脚本使用方法 (兼容使用xrayr执行，大小写不敏感): "
    echo "------------------------------------------"
    echo "XrayR                    - 显示管理菜单 (功能更多)"
    echo "XrayR start              - 启动 XrayR"
    echo "XrayR stop               - 停止 XrayR"
    echo "XrayR restart            - 重启 XrayR"
    echo "XrayR status             - 查看 XrayR 状态"
    echo "XrayR enable             - 设置 XrayR 开机自启"
    echo "XrayR disable            - 取消 XrayR 开机自启"
    echo "XrayR log                - 查看 XrayR 日志"
    echo "XrayR update             - 更新 XrayR"
    echo "XrayR update x.x.x       - 更新 XrayR 指定版本"
    echo "XrayR config             - 显示配置文件内容"
    echo "XrayR install            - 安装 XrayR"
    echo "XrayR uninstall          - 卸载 XrayR"
    echo "XrayR version            - 查看 XrayR 版本"
    echo "------------------------------------------"
}

echo -e "${green}开始安装${plain}"
install_base
# install_acme
install_XrayR $1
