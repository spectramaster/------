#!/bin/sh
# 论坛链接: https://1024.day
# 脚本名称: ws.sh
# 脚本功能: 安装纯WebSocket模式的V2Ray代理服务（不带TLS加密）
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 简单轻量配置，不需要域名和SSL证书

# 引入共享库，使用点号引入脚本，这样可以在当前shell环境中执行
. ./common.sh

# 执行初始化检查，确保脚本以root权限运行
check_root
# 设置系统时区为亚洲/上海
set_timezone

# 设置V2Ray服务参数
# 生成随机 UUID (用于客户端认证)
v2uuid=$(gen_uuid)
# 生成随机路径 (用于 WebSocket 的路径)
v2path=$(gen_path)
# 随机生成一个2000-65000范围内的端口号
v2port=$(gen_port)

# 安装和配置V2Ray的函数
install_v2ray(){    
    # 安装基本工具
    install_base
    
    # 使用官方脚本安装V2Ray
    # 该脚本会下载最新版本的V2Ray并设置服务
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
# 创建V2Ray配置文件，使用WebSocket模式（不带TLS）
cat >/usr/local/etc/v2ray/config.json<<EOF
{
  "inbounds": [
    {
      "port": $v2port,
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
        "security": "auto",
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

    # 启用并启动V2Ray服务
    enable_service v2ray
    
    # 清理安装文件
    clean_files ws.sh

    # 获取服务器IP地址
    serverIP=$(getIP)

# 创建客户端配置文件 (保存客户端连接信息)
cat >/usr/local/etc/v2ray/client.json<<EOF
{
===========配置参数=============
协议：VMess
地址：${serverIP}
端口：${v2port}
UUID：${v2uuid}
加密方式：aes-128-gcm
传输协议：ws
路径：/${v2path}
注意：不需要打开tls
}
EOF

    # 清屏，准备显示客户端配置信息
    clear
}

# 输出客户端配置信息的函数
client_v2ray(){
    # 获取服务器IP地址
    serverIP=$(getIP)
    
    # 生成V2Ray连接链接
    # 将JSON格式的配置信息使用base64编码，生成vmess://开头的链接
    wslink=$(echo -n "{\"port\":${v2port},\"ps\":\"1024-ws\",\"id\":\"${v2uuid}\",\"aid\":0,\"v\":2,\"add\":\"${serverIP}\",\"type\":\"none\",\"path\":\"/${v2path}\",\"net\":\"ws\",\"method\":\"auto\"}" | base64 -w 0)

    # 显示安装完成信息
    show_completion
    # 输出V2Ray配置参数
    echo "===========v2ray配置参数============"
    echo "协议：VMess"
    echo "地址：${serverIP}"
    echo "端口：${v2port}"
    echo "UUID：${v2uuid}"
    echo "加密方式：aes-128-gcm"
    echo "传输协议：ws"
    echo "路径：/${v2path}"
    echo "注意：不需要打开tls"
    echo "===================================="
    # 输出客户端可直接导入的URI链接
    echo "vmess://${wslink}"
    echo
}

# 执行安装和配置函数
install_v2ray
client_v2ray