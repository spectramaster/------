##!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: tcp-wss.sh
# 脚本功能: 提供菜单选项安装不同类型的代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 一键安装多种代理服务，包括Shadowsocks、V2Ray+WSS、Reality和Hysteria2

# 引入共享库，使用点号引入脚本，这样可以在当前shell环境中执行
. ./common.sh

# 执行初始化检查，确保脚本以root权限运行
check_root
# 设置系统时区为亚洲/上海
set_timezone

# 设置通用参数
# 生成随机路径 (用于 WebSocket 的路径)
v2path=$(gen_path)
# 生成随机 UUID (用于客户端认证)
v2uuid=$(gen_uuid)
# 随机生成一个端口号 (用于 Shadowsocks)
ssport=$(gen_port)

# 安装前检查函数 (用于V2ray+WSS安装)
install_precheck(){
    # 提示用户输入已解析的域名
    echo "====输入已经DNS解析好的域名===="
    read domain

    # 交互式设置端口，等待15秒，默认为443
    read -t 15 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)："  getPort
    if [ -z $getPort ];then
        getPort=443
    fi
    
    # 安装基本工具
    install_base
    # 安装网络工具包，用于检查端口占用
    install_debian_tools "net-tools"
    install_centos_tools "net-tools"

    # 等待3秒，确保系统稳定
    sleep 3
    # 检查80和443端口是否被占用
    isPort=`netstat -ntlp| grep -E ':80 |:443 '`
    if [ "$isPort" != "" ];then
        # 如果端口被占用，显示错误信息并退出
        clear
        echo " ================================================== "
        echo " 80或443端口被占用，请先释放端口再运行此脚本"
        echo
        echo " 端口占用信息如下："
        echo $isPort
        echo " ================================================== "
        exit 1
    fi
}

# 安装和配置Nginx的函数
install_nginx(){
    # 根据系统类型安装Nginx和其他必要组件
    install_debian_tools "nginx cron socat"
    install_centos_tools "nginx cronie socat"

# 创建Nginx配置文件
cat >/etc/nginx/nginx.conf<<EOF
# 设置nginx进程和工作进程数
pid /var/run/nginx.pid;
worker_processes auto;
worker_rlimit_nofile 51200;
events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}
http {
    # 基本HTTP设置
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

    # HTTP服务器，将HTTP请求重定向到HTTPS
    server {
        listen 80;
        listen [::]:80;
        server_name $domain;
        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }
    
    # HTTPS服务器，提供SSL加密和V2Ray的WebSocket代理
    server {
        listen $getPort ssl http2;
        listen [::]:$getPort ssl http2;
        server_name $domain;
        # SSL设置
        ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:HIGH:!aNULL:!MD5:!RC4:!DHE;
        ssl_prefer_server_ciphers on;
        ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;        
        # 默认页面
        location / {
            default_type text/plain;
            return 200 "Hello World !";
        }        
        # V2Ray WebSocket路径，代理到本地V2Ray服务
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

# 获取SSL证书的函数
acme_ssl(){    
    # 安装acme.sh脚本用于自动申请SSL证书
    curl https://get.acme.sh | sh -s email=my@example.com
    # 创建证书存储目录
    mkdir -p /etc/letsencrypt/live/$domain
    # 申请SSL证书
    # --issue: 申请新证书
    # -d: 指定域名
    # --standalone: 使用独立模式，暂时启动一个web服务器
    # --keylength ec-256: 使用ECC算法，密钥长度256位
    # --pre-hook: 证书申请前停止Nginx
    # --post-hook: 证书申请后安装证书并重启Nginx
    ~/.acme.sh/acme.sh --issue -d $domain --standalone --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "~/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /etc/letsencrypt/live/$domain/fullchain.pem --key-file /etc/letsencrypt/live/$domain/privkey.pem --reloadcmd \"systemctl start nginx\""
}

# 安装V2Ray的函数
install_v2ray(){    
    # 使用官方脚本安装V2Ray
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
# 创建V2Ray配置文件，使用WebSocket + TLS
cat >/usr/local/etc/v2ray/config.json<<EOF
{
  "inbounds": [
    {
      "port": 8080,          # 本地监听端口
      "protocol": "vmess",   # 使用VMess协议
      "settings": {
        "clients": [
          {
            "id": "$v2uuid"  # 客户端认证ID
          }
        ]
      },
      "streamSettings": {
        "network": "ws",     # 使用WebSocket传输
        "wsSettings": {
        "path": "/$v2path"   # WebSocket路径
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom", # 出站连接直接转发
      "settings": {}
    }
  ]
}
EOF

    # 启用并启动V2Ray服务和Nginx服务
    enable_service v2ray && systemctl restart nginx.service
    
    # 清理安装文件
    clean_files install-release.sh

# 创建客户端配置文件 (保存客户端连接信息)
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

    # 清屏，准备显示客户端配置信息
    clear
}

# 安装Shadowsocks-rust的函数
install_ssrust(){
    # 下载并运行Shadowsocks安装脚本
    wget https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/ss-rust.sh && bash ss-rust.sh
}

# 安装Reality代理的函数
install_reality(){
    # 下载并运行Reality安装脚本
    wget https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/reality.sh && bash reality.sh
}

# 安装Hysteria2代理的函数
install_hy2(){
    # 下载并运行Hysteria2安装脚本
    wget https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/hy2.sh && bash hy2.sh
}

# 输出V2Ray客户端配置信息的函数
client_v2ray(){
    # 生成V2Ray连接链接
    # 构建客户端配置JSON并使用base64编码
    wslink=$(echo -n "{\"port\":${getPort},\"ps\":\"1024-wss\",\"tls\":\"tls\",\"id\":\"${v2uuid}\",\"aid\":0,\"v\":2,\"host\":\"${domain}\",\"type\":\"none\",\"path\":\"/${v2path}\",\"net\":\"ws\",\"add\":\"${domain}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${domain}\",\"sni\":\"${domain}\"}" | base64 -w 0)

    # 显示安装完成信息
    show_completion
    # 输出V2Ray配置参数
    echo "===========v2ray配置参数============"
    echo "协议：VMess"
    echo "地址：${domain}"
    echo "端口：${getPort}"
    echo "UUID：${v2uuid}"
    echo "加密方式：aes-128-gcm"
    echo "传输协议：ws"
    echo "路径：/${v2path}"
    echo "底层传输：tls"
    echo "注意：8080是免流端口不需要打开tls"
    echo "===================================="
    # 输出客户端可直接导入的URI链接
    echo "vmess://${wslink}"
    echo
}

# 显示主菜单的函数
start_menu(){
    # 清屏
    clear
    # 显示菜单标题和选项
    echo " ================================================== "
    echo " 论坛：https://1024.day                              "
    echo " 介绍：一键安装SS-Rust，v2ray+wss，Reality或Hysteria2    "
    echo " 系统：Ubuntu、Debian、CentOS                        "
    echo " ================================================== "
    echo
    echo " 1. 安装 Shadowsocks-rust"
    echo " 2. 安装 v2ray+ws+tls"
    echo " 3. 安装 Reality"
    echo " 4. 安装 Hysteria2"
    echo " 0. 退出脚本"
    echo
    # 读取用户输入
    read -p "请输入数字:" num
    # 根据用户输入执行相应操作
    case "$num" in
    1)
    # 安装Shadowsocks-rust
    install_ssrust
    ;;
    2)
    # 安装V2Ray+WebSocket+TLS
    install_precheck
    install_nginx
    acme_ssl
    install_v2ray
    client_v2ray
    ;;
    3)
    # 安装Reality
    install_reality
    ;;
    4)
    # 安装Hysteria2
    install_hy2
    ;;
    0)
    # 退出脚本
    exit 1
    ;;
    *)
    # 输入无效，显示错误信息并重新显示菜单
    clear
    echo "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

# 启动主菜单
start_menu