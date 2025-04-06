#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 V2Ray WebSocket 代理服务的脚本
# 不带 TLS 加密的纯 WebSocket 模式，比 WSS 配置更简单，但安全性较低

# 获取脚本所在目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# 下载共享库
if [ ! -f "${SCRIPT_DIR}/common.sh" ]; then
    echo "下载共享库..."
    wget -q -O "${SCRIPT_DIR}/common.sh" https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/common.sh
    chmod +x "${SCRIPT_DIR}/common.sh"
fi

# 导入共享库
. "${SCRIPT_DIR}/common.sh"

# 设置脚本名称（用于日志）
SCRIPT_NAME="V2Ray WebSocket 安装脚本"
log_message $INFO "$SCRIPT_NAME 开始执行"

# 检查root权限
check_root

# 设置时区
set_timezone

# 生成随机参数
v2uuid=$(random_uuid)
v2path=$(random_path)
v2port=$(random_port)

# 定义安装步骤总数（用于显示进度）
TOTAL_STEPS=4
CURRENT_STEP=0

# 检查和准备环境
prepare_environment() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "准备环境"
    
    # 检查端口是否被占用
    log_message $INFO "检查端口: $v2port"
    if ! check_ports $v2port; then
        log_message $WARNING "端口 $v2port 已被占用，重新生成端口"
        v2port=$(random_port)
        
        # 再次检查新端口
        if ! check_ports $v2port; then
            handle_error $ERR_PORT_OCCUPIED "无法找到可用的端口" 1
            return 1
        }
    }
    
    log_message $INFO "使用端口: $v2port"
    log_message $INFO "随机路径: /$v2path"
    log_message $INFO "随机UUID: $v2uuid"
    
    log_message $INFO "环境检查完成"
    return 0
}

# 安装系统更新和必要工具
install_dependencies() { 
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "安装依赖"
    
    # 使用共享库函数安装基本软件包
    log_message $INFO "安装基本软件包"
    install_base_packages >/dev/null
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_DEPENDENCY "基本软件包安装失败" 0
        return 1
    }
    
    log_message $INFO "依赖安装完成"
    return 0
}

# 安装和配置V2Ray
install_v2ray(){
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "安装配置 V2Ray"
    
    # 从V2Ray官方仓库下载并运行安装脚本
    log_message $INFO "下载V2Ray安装脚本"
    exec_with_check "bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)" \
                   "V2Ray安装成功" "V2Ray安装失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "V2Ray安装失败" 1
        return 1
    }
    
    # 检查V2Ray是否安装成功
    if [ ! -f "/usr/local/bin/v2ray" ]; then
        handle_error $ERR_INSTALLATION "V2Ray执行文件不存在，安装可能失败" 1
        return 1
    }
    
    # 创建V2Ray配置目录（如果不存在）
    if [ ! -d "/usr/local/etc/v2ray" ]; then
        mkdir -p /usr/local/etc/v2ray
        log_message $INFO "创建配置目录: /usr/local/etc/v2ray"
    }
    
    # 创建V2Ray配置文件
    log_message $INFO "创建V2Ray配置文件"
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

    # 检查配置文件是否创建成功
    if [ ! -e "/usr/local/etc/v2ray/config.json" ]; then
        handle_error $ERR_CONFIGURATION "V2Ray配置文件创建失败" 0
        return 1
    }
    
    log_message $INFO "V2Ray安装和配置完成"
    return 0
}

# 启动V2Ray服务并保存配置
start_v2ray_service() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "启动服务并保存配置"
    
    # 启用并重启V2Ray服务
    log_message $INFO "启动V2Ray服务"
    exec_with_check "systemctl enable v2ray.service && systemctl restart v2ray.service" \
                   "V2Ray服务启动成功" "V2Ray服务启动失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_SERVICE "V2Ray服务启动失败" 0
        
        # 检查服务状态以获取更多信息
        log_message $ERROR "V2Ray服务状态:"
        systemctl status v2ray.service
        
        return 1
    }
    
    # 检查服务是否正常运行
    if ! systemctl is-active --quiet v2ray.service; then
        handle_error $ERR_SERVICE "V2Ray服务未正常运行" 0
        return 1
    }
    
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/ws.sh"

    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 保存客户端配置信息到文件
    log_message $INFO "保存客户端配置信息"
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

    log_message $INFO "服务启动和配置保存完成"
    clear
    return 0
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

# 主函数
main() {
    # 设置错误处理为严格模式
    set_auto_exit 1
    
    # 初始化日志
    init_log clear
    
    log_message $INFO "开始安装 V2Ray WebSocket"
    
    # 执行安装步骤
    prepare_environment && \
    install_dependencies && \
    install_v2ray && \
    start_v2ray_service
    
    # 检查安装结果
    if [ $? -eq 0 ]; then
        log_message $INFO "V2Ray WebSocket 安装成功"
        client_v2ray
    else
        log_message $ERROR "V2Ray WebSocket 安装失败，请查看日志: $LOG_FILE"
        echo
        echo "安装失败，请查看日志文件: $LOG_FILE"
        echo
        return 1
    fi
    
    return 0
}

# 执行主函数
main