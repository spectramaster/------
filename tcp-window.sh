#!/bin/sh
# Issues https://1024.day
# 这是一个用于优化系统TCP网络参数的脚本
# 主要提高代理服务的网络性能，减少延迟，提升吞吐量

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
SCRIPT_NAME="TCP窗口优化脚本"
log_message $INFO "$SCRIPT_NAME 开始执行"

# 检查root权限
check_root

# 定义安装步骤总数（用于显示进度）
TOTAL_STEPS=4
CURRENT_STEP=0

# 优化系统资源限制
optimize_system_limits() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "优化系统资源限制"
    
    log_message $INFO "修改系统资源限制配置文件"
    
cat >/etc/security/limits.conf<<EOF
* soft     nproc          655360
* hard     nproc          655360
* soft     nofile         655360
* hard     nofile         655360

root soft     nproc          655360
root hard     nproc          655360
root soft     nofile         655360
root hard     nofile         655360

bro soft     nproc          655360
bro hard     nproc          655360
bro soft     nofile         655360
bro hard     nofile         655360
EOF

    # 检查配置文件是否创建成功
    if [ ! -e "/etc/security/limits.conf" ]; then
        handle_error $ERR_CONFIGURATION "系统资源限制配置文件创建失败" 0
        return 1
    }
    
    log_message $INFO "系统资源限制修改成功"
    return 0
}

# 配置PAM模块
configure_pam() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "配置PAM模块"
    
    log_message $INFO "配置PAM会话模块"
    
    # 确保PAM会话启用系统资源限制
    echo "session required pam_limits.so" >> /etc/pam.d/common-session
    echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    
    # 修改systemd默认文件描述符限制
    echo "DefaultLimitNOFILE=655360" >> /etc/systemd/system.conf
    
    log_message $INFO "PAM模块配置完成"
    return 0
}

# 优化TCP网络参数
optimize_tcp_params() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "优化TCP网络参数"
    
    log_message $INFO "修改TCP网络参数配置文件"
    
cat >/etc/sysctl.conf<<EOF
fs.file-max = 655360
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_slow_start_after_idle = 0
#net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 8192 262144 167772160
net.ipv4.tcp_wmem = 4096 16384 83886080
#net.ipv4.udp_rmem_min = 8192
#net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_adv_win_scale = -2
net.ipv4.tcp_notsent_lowat = 131072
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    # 检查配置文件是否创建成功
    if [ ! -e "/etc/sysctl.conf" ]; then
        handle_error $ERR_CONFIGURATION "TCP网络参数配置文件创建失败" 0
        return 1
    }
    
    # 尝试立即应用部分网络参数（不必要，但可以提前确认参数有效性）
    log_message $INFO "测试网络参数有效性"
    if ! sysctl -p >/dev/null 2>&1; then
        log_message $WARNING "网络参数应用时出现警告，某些参数可能不被支持"
    }
    
    log_message $INFO "TCP网络参数配置完成"
    return 0
}

# 清理并重启
cleanup_and_reboot() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    show_progress $CURRENT_STEP $TOTAL_STEPS "清理并重启系统"
    
    # 删除安装脚本
    log_message $INFO "清理安装脚本"
    rm -f ${SCRIPT_DIR}/tcp-window.sh
    
    log_message $INFO "优化完成，系统将在3秒后重启以应用所有更改"
    
    # 确认重启
    if confirm "是否立即重启系统以应用更改？" "y"; then
        log_message $INFO "用户确认重启，系统将在3秒后重启"
        echo "系统将在3秒后重启..."
        sleep 3 && reboot
    else
        log_message $INFO "用户取消重启，建议手动重启系统以应用所有更改"
        echo "建议手动重启系统以应用所有更改"
    }
    
    return 0
}

# 主函数
main() {
    # 设置错误处理为严格模式
    set_auto_exit 1
    
    # 初始化日志
    init_log clear
    
    # 打印标题
    print_header "TCP网络优化脚本"
    
    log_message $INFO "开始TCP网络优化配置"
    
    echo "此脚本将优化系统TCP网络参数，提高代理服务的网络性能。"
    echo "优化过程将修改以下配置文件："
    echo "- /etc/security/limits.conf"
    echo "- /etc/pam.d/common-session"
    echo "- /etc/pam.d/common-session-noninteractive"
    echo "- /etc/systemd/system.conf"
    echo "- /etc/sysctl.conf"
    echo
    
    # 询问用户是否继续
    if ! confirm "是否继续？" "y"; then
        log_message $INFO "用户取消操作"
        echo "操作已取消"
        return 0
    }
    
    # 执行优化步骤
    optimize_system_limits && \
    configure_pam && \
    optimize_tcp_params && \
    cleanup_and_reboot
    
    # 检查优化结果
    if [ $? -eq 0 ]; then
        log_message $INFO "TCP网络优化配置成功"
    else
        log_message $ERROR "TCP网络优化配置失败，请查看日志: $LOG_FILE"
        echo
        echo "优化失败，请查看日志文件: $LOG_FILE"
        echo
        return 1
    fi
    
    return 0
}

# 执行主函数
main