#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: hy2.sh
# 脚本功能: 安装 Hysteria2 代理服务
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上

# 引入共享库，使用点号引入脚本，这样可以在当前shell环境中执行
. ./common.sh

# 执行初始化检查，确保脚本以root权限运行
check_root
# 设置系统时区为亚洲/上海
set_timezone

# 设置Hysteria2服务参数
# 使用UUID作为密码，提供较高的安全性
hyPasswd=$(gen_uuid)
# 随机生成一个2000-65000范围内的端口号
getPort=$(gen_port)

# 安装 Hysteria2 的主函数
install_hy2(){
    # 安装基本依赖包
    install_base
    
    # 使用官方脚本安装 Hysteria2
    # 该脚本会自动检测系统类型和架构，并安装适合的版本
    bash <(curl -fsSL https://get.hy2.sh/)
    
    # 创建配置目录
    mkdir -p /etc/hysteria/
    
    # 生成自签名TLS证书，使用椭圆曲线加密算法(EC)
    # 1. 创建椭圆曲线参数
    # 2. 生成无密码保护的私钥和自签名证书
    # 3. 设置证书主题为bing.com
    # 4. 设置证书有效期为36500天(约100年)
    # 5. 设置证书和私钥的所有者为hysteria用户
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500 && chown hysteria /etc/hysteria/server.key && chown hysteria /etc/hysteria/server.crt

# 创建 Hysteria2 服务器配置文件
cat >/etc/hysteria/config.yaml <<EOF
# 监听端口，格式为 :端口号
listen: :$getPort
# TLS证书配置
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

# 认证配置
auth:
  type: password
  password: $hyPasswd
  
# 伪装配置，用于绕过DPI检测
masquerade:
  type: proxy
  proxy:
    url: https://bing.com
    rewriteHost: true
# QUIC协议参数配置，用于优化性能
quic:
  initStreamReceiveWindow: 26843545 
  maxStreamReceiveWindow: 26843545 
  initConnReceiveWindow: 67108864 
  maxConnReceiveWindow: 67108864 
EOF

    # 启用并重启Hysteria2服务，然后显示服务状态
    enable_service hysteria-server && systemctl status --no-pager hysteria-server.service
    
    # 清理安装文件
    clean_files hy2.sh

    # 获取服务器IP地址
    serverIP=$(getIP)

# 创建客户端配置文件 (保存客户端连接信息)
cat >/etc/hysteria/hyclient.json<<EOF
{
===========配置参数=============
代理模式：Hysteria2
地址：${serverIP}
端口：${getPort}
密码：${hyPasswd}
SNI：bing.com
传输协议：tls
跳过证书验证：ture
====================================
hysteria2://$(echo -n "${hyPasswd}@${serverIP}:${getPort}/?insecure=1&sni=bing.com#1024-Hysteria2")
}
EOF

    # 清屏，准备显示客户端配置信息
    clear
}

# 输出客户端配置信息的函数
client_hy2(){
    # 获取服务器IP地址
    serverIP=$(getIP)
    
    # 生成 Hysteria2 连接链接
    # 格式: hysteria2://密码@IP:端口/?insecure=1&sni=bing.com#备注名
    hylink=$(echo -n "${hyPasswd}@${serverIP}:${getPort}/?insecure=1&sni=bing.com#1024-Hysteria2")

    # 显示安装完成信息
    show_completion
    # 输出Hysteria2配置参数
    echo "===========Hysteria2配置参数============"
    echo
    echo "地址：${serverIP}"
    echo "端口：${getPort}"
    echo "密码：${hyPasswd}"
    echo "SNI：bing.com"
    echo "传输协议：tls"
    echo "打开跳过证书验证，true"
    echo
    echo "========================================="
    # 输出客户端可直接导入的URI链接
    echo "hysteria2://${hylink}"
    echo
}

# 执行安装和配置函数
install_hy2
client_hy2