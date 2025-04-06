#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装多种代理服务的一键脚本
# 支持 Shadowsocks-rust、V2ray+WSS、Reality 和 Hysteria2 代理服务

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 下载共享库
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    echo "下载共享库..."
    wget -q -O "${SCRIPT_DIR}/common.sh" https://raw.githubusercontent.com/spectramaster/vpn/main/common.sh
    chmod +x "${SCRIPT_DIR}/common.sh"
fi

# 导入共享库
. "${SCRIPT_DIR}/common.sh"

# 设置脚本名称（用于日志）
SCRIPT_NAME="代理服务安装脚本"
log_message $INFO "$SCRIPT_NAME 开始执行"

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
    log_message $INFO "开始安装前检查"
    
    # 提示用户输入已解析好的域名
    echo "====输入已经DNS解析好的域名===="
    read domain
    
    if [ -z "$domain" ]; then
        handle_error $ERR_CONFIGURATION "域名不能为空" 1
        return 1
    fi
    
    log_message $INFO "用户输入域名: $domain"

    # 提示用户输入端口号，默认为443(HTTPS标准端口)
    read -t 15 -p "回车或等待15秒为默认端口443，或者自定义端口请输入(1-65535)："  getPort
    if [ -z $getPort ]; then
        getPort=443
        log_message $INFO "使用默认端口: 443"
    else
        log_message $INFO "用户指定端口: $getPort"
        
        # 验证端口范围
        if ! [[ "$getPort" =~ ^[0-9]+$ ]] || [ "$getPort" -lt 1 ] || [ "$getPort" -gt 65535 ]; then
            handle_error $ERR_CONFIGURATION "无效的端口号: $getPort (必须在1-65535范围内)" 1
            return 1
        fi
    fi
    
    # 安装基本软件包
    log_message $INFO "安装基本软件包"
    install_base_packages >/dev/null
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_DEPENDENCY "基本软件包安装失败" 0
        return 1
    fi

    log_message $INFO "检查端口占用情况"
    # 检查80和443端口是否被占用
    if ! check_ports 80 443; then
        handle_error $ERR_PORT_OCCUPIED "80或443端口被占用，请先释放端口再运行此脚本" 1
        return 1
    fi
    
    log_message $INFO "安装前检查完成"
    return 0
}

# 安装和配置Nginx服务器
install_nginx(){
    log_message $INFO "开始安装和配置Nginx"
    
    # 根据系统类型安装Nginx
    if [ -f "/usr/bin/apt-get" ]; then
        exec_with_check "apt-get install -y nginx cron" \
                      "Nginx安装成功(Debian/Ubuntu)" "Nginx安装失败" 0
    else
        exec_with_check "yum install -y nginx cronie" \
                      "Nginx安装成功(CentOS)" "Nginx安装失败" 0
    fi
    
    # 创建Nginx配置文件
    log_message $INFO "创建Nginx配置文件"
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

    # 检查配置文件是否创建成功
    if [ ! -e "/etc/nginx/nginx.conf" ]; then
        handle_error $ERR_CONFIGURATION "Nginx配置文件创建失败" 0
        return 1
    fi
    
    log_message $INFO "Nginx配置文件创建成功"
    return 0
}

# 申请并安装SSL证书
acme_ssl(){
    log_message $INFO "开始申请SSL证书"
    
    # 安装acme.sh证书管理工具
    log_message $INFO "安装acme.sh"
    exec_with_check "curl https://get.acme.sh | sh -s email=my@example.com" \
                   "acme.sh安装成功" "acme.sh安装失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "acme.sh安装失败" 0
        return 1
    fi
    
    # 创建证书存放目录
    log_message $INFO "创建证书目录"
    mkdir -p /etc/letsencrypt/live/$domain
    
    # 申请并安装证书
    log_message $INFO "申请SSL证书: $domain"
    ~/.acme.sh/acme.sh --issue -d $domain --standalone --keylength ec-256 --pre-hook "systemctl stop nginx" --post-hook "~/.acme.sh/acme.sh --installcert -d $domain --ecc --fullchain-file /etc/letsencrypt/live/$domain/fullchain.pem --key-file /etc/letsencrypt/live/$domain/privkey.pem --reloadcmd \"systemctl start nginx\""
    
    # 检查证书是否申请成功
    if [ ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$domain/privkey.pem" ]; then
        handle_error $ERR_INSTALLATION "SSL证书申请失败" 0
        return 1
    fi
    
    log_message $INFO "SSL证书申请成功"
    return 0
}

# 安装和配置V2Ray
install_v2ray(){
    log_message $INFO "开始安装V2Ray"
    
    # 从V2Ray官方仓库下载并运行安装脚本
    log_message $INFO "下载V2Ray安装脚本"
    exec_with_check "bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)" \
                   "V2Ray安装成功" "V2Ray安装失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "V2Ray安装失败" 0
        return 1
    }
    
    # 创建V2Ray配置文件
    log_message $INFO "创建V2Ray配置文件"
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

    # 检查配置文件是否创建成功
    if [ ! -e "/usr/local/etc/v2ray/config.json" ]; then
        handle_error $ERR_CONFIGURATION "V2Ray配置文件创建失败" 0
        return 1
    }
    
    # 启用并重启V2Ray服务和Nginx服务
    log_message $INFO "启动V2Ray和Nginx服务"
    exec_with_check "systemctl enable v2ray.service && systemctl restart v2ray.service && systemctl restart nginx.service" \
                   "V2Ray和Nginx服务启动成功" "V2Ray和Nginx服务启动失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_SERVICE "V2Ray服务启动失败" 0
        return 1
    }
    
    # 检查服务是否正常运行
    if ! systemctl is-active --quiet v2ray.service; then
        handle_error $ERR_SERVICE "V2Ray服务未正常运行" 0
        return 1
    }
    
    if ! systemctl is-active --quiet nginx.service; then
        handle_error $ERR_SERVICE "Nginx服务未正常运行" 0
        return 1
    }
    
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/install-release.sh"

    # 保存客户端配置信息到文件
    log_message $INFO "保存客户端配置信息"
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

    log_message $INFO "V2Ray安装配置完成"
    clear
    return 0
}

# 安装Shadowsocks-rust
install_ssrust(){
    log_message $INFO "开始安装Shadowsocks-rust"
    
    # 下载并运行Shadowsocks-rust安装脚本
    log_message $INFO "下载Shadowsocks-rust安装脚本"
    download_file "https://raw.githubusercontent.com/spectramaster/vpn/main/ss-rust.sh" "${SCRIPT_DIR}/ss-rust.sh" 1
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_NETWORK "Shadowsocks-rust安装脚本下载失败" 0
        return 1
    }
    
    # 添加执行权限
    chmod +x "${SCRIPT_DIR}/ss-rust.sh"
    
    # 运行安装脚本
    log_message $INFO "运行Shadowsocks-rust安装脚本"
    bash "${SCRIPT_DIR}/ss-rust.sh"
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "Shadowsocks-rust安装失败" 0
        return 1
    }
    
    log_message $INFO "Shadowsocks-rust安装成功"
    return 0
}

# 安装Reality
install_reality(){
    log_message $INFO "开始安装Reality"
    
    # 下载并运行Reality安装脚本
    log_message $INFO "下载Reality安装脚本"
    download_file "https://raw.githubusercontent.com/spectramaster/vpn/main/reality.sh" "${SCRIPT_DIR}/reality.sh" 1
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_NETWORK "Reality安装脚本下载失败" 0
        return 1
    }
    
    # 添加执行权限
    chmod +x "${SCRIPT_DIR}/reality.sh"
    
    # 运行安装脚本
    log_message $INFO "运行Reality安装脚本"
    bash "${SCRIPT_DIR}/reality.sh"
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "Reality安装失败" 0
        return 1
    }
    
    log_message $INFO "Reality安装成功"
    return 0
}

# 安装Hysteria2
install_hy2(){
    log_message $INFO "开始安装Hysteria2"
    
    # 下载并运行Hysteria2安装脚本
    log_message $INFO "下载Hysteria2安装脚本"
    download_file "https://raw.githubusercontent.com/spectramaster/vpn/main/hy2.sh" "${SCRIPT_DIR}/hy2.sh" 1
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_NETWORK "Hysteria2安装脚本下载失败" 0
        return 1
    }
    
    # 添加执行权限
    chmod +x "${SCRIPT_DIR}/hy2.sh"
    
    # 运行安装脚本
    log_message $INFO "运行Hysteria2安装脚本"
    bash "${SCRIPT_DIR}/hy2.sh"
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "Hysteria2安装失败" 0
        return 1
    }
    
    log_message $INFO "Hysteria2安装成功"
    return 0
}

# 显示V2Ray客户端配置信息
client_v2ray(){
    log_message $INFO "生成V2Ray客户端配置信息"
    
    # 生成V2Ray客户端配置链接
    wslink=$(echo -n "{\"port\":${getPort},\"ps\":\"1024-wss\",\"tls\":\"tls\",\"id\":\"${v2uuid}\",\"aid\":0,\"v\":2,\"host\":\"${domain}\",\"type\":\"none\",\"path\":\"/${v2path}\",\"net\":\"ws\",\"add\":\"${domain}\",\"allowInsecure\":0,\"method\":\"none\",\"peer\":\"${domain}\",\"sni\":\"${domain}\"}" | base64 -w 0)

    # 构建配置信息字符串
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

    # 使用共享库函数显示配置信息
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
    log_message $INFO "用户选择: $num"
    
    case "$num" in
    1)
    install_ssrust
    ;;
    2)
    install_precheck && \
    install_nginx && \
    acme_ssl && \
    install_v2ray && \
    client_v2ray
    
    if [ $? -ne 0 ]; then
        log_message $ERROR "V2Ray+WSS安装过程中出现错误，请查看日志: $LOG_FILE"
        echo
        echo "安装失败，请查看日志文件: $LOG_FILE"
        echo
    fi
    ;;
    3)
    install_reality
    ;;
    4)
    install_hy2
    ;;
    0)
    log_message $INFO "用户选择退出脚本"
    exit 0
    ;;
    *)
    clear
    log_message $WARNING "用户输入无效选项: $num"
    echo "请输入正确数字"
    sleep 2s
    start_menu
    ;;
    esac
}

# 主函数
main() {
    # 设置错误处理为严格模式
    set_auto_exit 1
    
    # 初始化日志
    init_log clear
    
    # 启动主菜单
    start_menu
    
    log_message $INFO "脚本执行完成"
    return 0
}

# 执行主函数
main