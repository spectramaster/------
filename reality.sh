#!/bin/sh
# forum: https://1024.day
# 这是一个用于安装 Xray Reality 代理服务的脚本
# Reality是一种新型的代理协议，无需域名和证书，安全性高

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
SCRIPT_NAME="Reality 安装脚本"
log_message $INFO "$SCRIPT_NAME 开始执行"

# 检查root权限
check_root

# 设置时区
set_timezone

# 生成随机UUID作为用户标识
v2uuid=$(random_uuid)

# 定义安装步骤总数（用于显示进度）
TOTAL_STEPS=3
CURRENT_STEP=0

# 获取端口号
get_port() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "配置端口"
    
    # 提示用户输入端口号，15秒内无输入则默认使用443端口
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
    
    # 检查端口是否被占用
    if ! check_ports $getPort; then
        handle_error $ERR_PORT_OCCUPIED "端口 $getPort 已被占用" 0
        # 提示用户重新输入端口
        read -p "请输入其他端口号(1-65535)："  getPort
        
        if [ -z $getPort ] || ! [[ "$getPort" =~ ^[0-9]+$ ]] || [ "$getPort" -lt 1 ] || [ "$getPort" -gt 65535 ]; then
            handle_error $ERR_CONFIGURATION "无效的端口号" 1
            return 1
        fi
        
        # 再次检查新端口是否被占用
        if ! check_ports $getPort; then
            handle_error $ERR_PORT_OCCUPIED "端口 $getPort 仍然被占用" 1
            return 1
        fi
    }
    
    log_message $INFO "端口配置完成：$getPort"
    return 0
}

# 安装Xray
install_xray() { 
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "安装Xray"
    
    # 使用共享库函数安装基本软件包
    log_message $INFO "安装基本软件包"
    install_base_packages >/dev/null
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_DEPENDENCY "基本软件包安装失败" 0
        return 1
    }
    
    # 从Xray官方仓库下载并运行安装脚本
    log_message $INFO "下载并安装Xray"
    exec_with_check "bash -c \"\$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)\" @ install" \
                   "Xray安装成功" "Xray安装失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_INSTALLATION "Xray安装失败" 1
        return 1
    }
    
    log_message $INFO "Xray安装完成"
    return 0
}

# 配置Reality
reconfig() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "配置Reality"
    
    # 检查Xray是否安装成功
    if [ ! -f "/usr/local/bin/xray" ]; then
        handle_error $ERR_INSTALLATION "Xray执行文件不存在，安装可能失败" 1
        return 1
    }
    
    # 生成X25519密钥对（Reality所需的身份认证密钥）
    log_message $INFO "生成X25519密钥对"
    reX25519Key=$(/usr/local/bin/xray x25519)
    
    if [ -z "$reX25519Key" ]; then
        handle_error $ERR_CONFIGURATION "X25519密钥生成失败" 1
        return 1
    }
    
    rePrivateKey=$(echo "${reX25519Key}" | head -1 | awk '{print $3}')
    rePublicKey=$(echo "${reX25519Key}" | tail -n 1 | awk '{print $3}')
    
    log_message $INFO "密钥对生成成功"
    log_message $INFO "私钥: ${rePrivateKey}"
    log_message $INFO "公钥: ${rePublicKey}"
    
    # 创建Xray配置目录（如果不存在）
    if [ ! -d "/usr/local/etc/xray" ]; then
        mkdir -p /usr/local/etc/xray
        log_message $INFO "创建配置目录: /usr/local/etc/xray"
    }

    # 创建Xray配置文件
    log_message $INFO "创建Xray配置文件"
cat >/usr/local/etc/xray/config.json<<EOF
{
    "inbounds": [
        {
            "port": $getPort,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "www.amazon.com:443",
                    "xver": 0,
                    "serverNames": [
                        "www.amazon.com",
                        "addons.mozilla.org",
                        "www.un.org",
                        "www.tesla.com"
                    ],
                    "privateKey": "$rePrivateKey",
                    "minClientVer": "",
                    "maxClientVer": "",
                    "maxTimeDiff": 0,
                    "shortIds": [
                        "88",
                        "123abc"
                    ]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "blocked"
        }
    ]    
}
EOF

    # 检查配置文件是否创建成功
    if [ ! -e "/usr/local/etc/xray/config.json" ]; then
        handle_error $ERR_CONFIGURATION "Xray配置文件创建失败" 0
        return 1
    }
    
    # 启用并重启Xray服务
    log_message $INFO "启动Xray服务"
    exec_with_check "systemctl enable xray.service && systemctl restart xray.service" \
                   "Xray服务启动成功" "Xray服务启动失败" 0
    
    if [ $? -ne 0 ]; then
        handle_error $ERR_SERVICE "Xray服务启动失败" 0
        
        # 检查服务状态以获取更多信息
        log_message $ERROR "Xray服务状态:"
        systemctl status xray.service
        
        return 1
    }
    
    # 检查服务是否正常运行
    if ! systemctl is-active --quiet xray.service; then
        handle_error $ERR_SERVICE "Xray服务未正常运行" 0
        return 1
    }
    
    # 删除安装脚本
    cleanup_files "${SCRIPT_DIR}/tcp-wss.sh" "${SCRIPT_DIR}/install-release.sh" "${SCRIPT_DIR}/reality.sh"

    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 保存客户端配置信息到文件
    log_message $INFO "保存客户端配置信息"
cat >/usr/local/etc/xray/reclient.json<<EOF
{
===========配置参数=============
代理模式：vless
地址：${server_ip}
端口：${getPort}
UUID：${v2uuid}
流控：xtls-rprx-vision
传输协议：tcp
Public key：${rePublicKey}
底层传输：reality
SNI: www.amazon.com
shortIds: 88
====================================
vless://${v2uuid}@${server_ip}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#1024-reality

}
EOF

    log_message $INFO "Reality配置完成"
    clear
    return 0
}

# 显示客户端配置信息
client_re(){
    # 获取服务器IP
    server_ip=$(get_ip)
    
    # 构建配置信息字符串
    config=$(cat <<EOF
代理模式：vless
地址：${server_ip}
端口：${getPort}
UUID：${v2uuid}
流控：xtls-rprx-vision
传输协议：tcp
Public key：${rePublicKey}
底层传输：reality
SNI: www.amazon.com
shortIds: 88
EOF
)

    # 生成链接
    link="vless://${v2uuid}@${server_ip}:${getPort}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.amazon.com&fp=chrome&pbk=${rePublicKey}&sid=88&type=tcp&headerType=none#1024-reality"
    
    # 使用共享库函数显示配置信息
    print_config "reality" "$config" "$link"
}

# 主函数
main() {
    # 设置错误处理为严格模式
    set_auto_exit 1
    
    # 初始化日志
    init_log clear
    
    log_message $INFO "开始安装 Reality"
    
    # 执行安装步骤
    get_port && \
    install_xray && \
    reconfig
    
    # 检查安装结果
    if [ $? -eq 0 ]; then
        log_message $INFO "Reality 安装成功"
        client_re
    else
        log_message $ERROR "Reality 安装失败，请查看日志: $LOG_FILE"
        echo
        echo "安装失败，请查看日志文件: $LOG_FILE"
        echo
        return 1
    fi
    
    return 0
}

# 执行主函数
main