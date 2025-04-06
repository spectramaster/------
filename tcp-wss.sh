#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装多种代理服务的一键脚本
# 支持 Shadowsocks-rust、V2ray+WSS、Reality 和 Hysteria2 代理服务

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 下载共享库
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    wget -q -O "${SCRIPT_DIR}/common.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/common.sh
    chmod +x "${SCRIPT_DIR}/common.sh"
fi

# 导入共享库
. "${SCRIPT_DIR}/common.sh"

# 检查root权限
check_root

# 设置时区
set_timezone

# 生成随机参数
v2path=$(random_path)
v2uuid=$(random_uuid)
ssport=$(random_port)

# 安装前的检查和准备工作
install_precheck(){
    # 提示用户输入已解析好的域名
    echo "====输入已经DNS解析好的域名===="
    read domain

    # 提示用户输入端口号，默认为443(HTTPS标准端口)
    read -t 15 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)："  getPort
    if [ -z $getPort ];then
        getPort=443
    fi
    
    # 安装基本软件包
    install_base_packages >/dev/null

    sleep 3
    # 检查80和443端口是否被占用
    if ! check_ports 80 443; then
        print_line
        echo " 80或443端口被占用，请先释放端口再运行此脚本"
        echo
        netstat -ntlp | grep -E ':80 |:443 '
        print_line
        exit 1
    fi
}

# 安装和配置Nginx服务器
install_nginx(){
    # 根据系统类型安装Nginx
    if [ -f "/usr/bin/apt-get" ];then
        apt-get install -y nginx cron
    else
        yum install -y nginx cronie
    fi

    # 创建Nginx配置文件
cat >/etc/nginx/nginx.conf<<EOF
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 51200;
events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}
http {
    server_tokens off;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 120s;
    keepalive_requests 10000;
    types_hash_max_size 2048;
    include /etc/nginx/mime.types;
    access_log off;
    error_log /dev/null;

    server {
        listen 80;
        listen [::]:80;
        server_name $domain;
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }
    
    server {
        listen $getPort ssl http2;
        listen [::]:$getPort ssl http2;
        server_name $domain;
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers on;
        ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;        
        location / {
            default_type text/plain;
            return 200 "Hello World !";
        }        
        location /$v2path {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$http_host;
        }
    }
}
EOF
}

# 申请并安装SSL证书
acme_ssl(){    
    curl https://get.acme.sh | sh -s email=my@example.com
    mkdir -p /etc/letsencrypt/live/$domain
    ~/.acme.sh/acme.sh --issue -d $domain --standalone --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "~/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /etc/letsencrypt/live/$domain/fullchain.pem --key-file /etc/letsencrypt/live/$domain/privkey.pem --reloadcmd \"systemctl start nginx\""
}

# 安装和配置V2Ray
install_v2ray(){    
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    # 创建V2Ray配置文件
cat >/usr/local/etc/v2ray/config.json<<EOF
{
  "inbounds": [
    {
      "port": 8080,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$v2uuid"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
        "path": "/$v2path"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF

    systemctl enable v2ray.service && systemctl restart v2ray.service && systemctl restart nginx.service
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/install-release.sh"

    # 保存客户端配置信息到文件
cat >/usr/local/etc/v2ray/client.json<<EOF
{
===========配置参数=============
协议：VMess
地址：${domain}
端口：${getPort}
UUID：${v2uuid}
加密方式：aes-128-gcm
传输协议：ws
路径：/${v2path}
底层传输：tls
注意：8080是免流端口不需要打开tls
}
EOF

    clear
}

# 安装Shadowsocks-rust
install_ssrust(){
    # 下载并运行Shadowsocks-rust安装脚本
    wget -O "${SCRIPT_DIR}/ss-rust.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/ss-rust.sh && bash "${SCRIPT_DIR}/ss-rust.sh"
}

# 安装Reality
install_reality(){
    # 下载并运行Reality安装脚本
    wget -O "${SCRIPT_DIR}/reality.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/reality.sh && bash "${SCRIPT_DIR}/reality.sh"
}

# 安装Hysteria2
install_hy2(){
    # 下载并运行Hysteria2安装脚本
    wget -O "${SCRIPT_DIR}/hy2.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/hy2.sh && bash "${SCRIPT_DIR}/hy2.sh"
}

# 显示V2Ray客户端配置信息
client_v2ray(){
    # 生成V2Ray客户端配置链接
    wslink=$(echo -n "{\"port\":${getPort},\"ps\":\"1024-wss\",\"tls\":\"tls\",\"id\":\"${v2uuid}\",\"aid\":0,\"v\":2,\"host\":\"${domain}\",\"type\":\"none\",\"path\":\"/${v2path}\",\"net\":\"ws\",\"add\":\"${domain}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${domain}\",\"sni\":\"${domain}\"}" | base64 -w 0)

    # 使用共享库函数显示配置信息
    config=$(cat <<EOF
协议：VMess
地址：${domain}
端口：${getPort}
UUID：${v2uuid}
加密方式：aes-128-gcm
传输协议：ws
路径：/${v2path}
底层传输：tls
注意：8080是免流端口不需要打开tls
EOF
)

    print_config "v2ray" "$config" "vmess://${wslink}"
}

# 显示主菜单并处理用户选择
start_menu(){
    print_header "一键安装SS-Rust，v2ray+wss，Reality或Hysteria2"
    
    echo " 1. 安装 Shadowsocks-rust"
    echo " 2. 安装 v2ray+ws+tls"
    echo " 3. 安装 Reality"
    echo " 4. 安装 Hysteria2"
    echo " 0. 退出脚本"
    echo
    
    read -p "请输入数字:" num
    case "$num" in
    1)
    install_ssrust
    ;;
    2)
    install_precheck
    install_nginx
    acme_ssl
    install_v2ray
    client_v2ray
    ;;
    3)
    install_reality
    ;;
    4)
    install_hy2
    ;;
    0)
    exit 0
    ;;
    *)
    clear
    echo "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

# 启动主菜单
start_menu