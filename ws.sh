#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 V2Ray WebSocket 代理服务的脚本
# 不带 TLS 加密的纯 WebSocket 模式，比 WSS 配置更简单，但安全性较低

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
v2uuid=$(random_uuid)
v2path=$(random_path)
v2port=$(random_port)

# 安装系统更新和必要工具
install_update(){ 
    # 使用共享库函数安装基本软件包
    install_base_packages >/dev/null
}

# 安装和配置V2Ray
install_v2ray(){    
    # 从V2Ray官方仓库下载并运行安装脚本
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    # 创建V2Ray配置文件
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

    # 启用并重启V2Ray服务
    systemctl enable v2ray.service && systemctl restart v2ray.service
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/ws.sh"

    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 保存客户端配置信息到文件
cat >/usr/local/etc/v2ray/client.json<<EOF
{
===========配置参数=============
协议：VMess
地址：${server_ip}
端口：${v2port}
UUID：${v2uuid}
加密方式：aes-128-gcm
传输协议：ws
路径：/${v2path}
注意：不需要打开tls
}
EOF

    clear
}

# 显示客户端配置信息
client_v2ray(){
    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 生成V2Ray客户端配置链接
    # 使用Base64编码JSON格式的配置信息
    wslink=$(echo -n "{\"port\":${v2port},\"ps\":\"1024-ws\",\"id\":\"${v2uuid}\",\"aid\":0,\"v\":2,\"add\":\"${server_ip}\",\"type\":\"none\",\"path\":\"/${v2path}\",\"net\":\"ws\",\"method\":\"auto\"}" | base64 -w 0)

    # 构建配置信息字符串
    config=$(cat <<EOF
协议：VMess
地址：${server_ip}
端口：${v2port}
UUID：${v2uuid}
加密方式：aes-128-gcm
传输协议：ws
路径：/${v2path}
注意：不需要打开tls
EOF
)

    # 使用共享库函数显示配置信息
    print_config "v2ray" "$config" "vmess://${wslink}"
}

# 执行安装流程
install_update
install_v2ray
client_v2ray