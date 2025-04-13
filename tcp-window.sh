#!/bin/sh
# 问题反馈链接: https://1024.day
# 脚本名称: tcp-window.sh (Enhanced Adaptive Version)
# 脚本功能: 根据系统内存和CPU核心数优化网络参数和资源限制
# 创建日期: 2025年4月13日 (修改日期: [当前日期])
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 动态调整参数以适应不同内存和CPU配置的服务器

# 增加错误处理：任何命令失败则立即退出
set -e

# 定义错误处理函数
error_exit() {
    echo "Error: $1" 1>&2
    exit 1
}

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
   error_exit "This script must be run as root."
fi

echo "Detecting system resources..."

# --- 获取内存信息 ---
mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ -z "$mem_total_kb" ] || [ "$mem_total_kb" -le 0 ]; then
    error_exit "Could not determine total system memory from /proc/meminfo."
fi
mem_total_mb=$((mem_total_kb / 1024))
mem_total_gb=$((mem_total_mb / 1024))
echo "Total Memory: ${mem_total_mb} MB (${mem_total_gb} GB)"

# --- 获取 CPU 核心数 ---
cpu_cores=$(nproc --all 2>/dev/null || grep -c ^processor /proc/cpuinfo || echo 1) # 提供备用方法
if [ -z "$cpu_cores" ] || [ "$cpu_cores" -le 0 ]; then
    echo "Warning: Could not determine CPU core count. Using default value: 1" >&2
    cpu_cores=1
fi
echo "CPU Cores: $cpu_cores"

# --- 参数计算 ---

# 1. fs.file-max (系统最大文件描述符)
#    主要基于内存，但高核心数可适当提高上限
#    估算: 每 GB 内存 10 万，最低 65536
#    基础值
fs_file_max_calc=$((mem_total_gb * 100000))
# 设置下限
if [ "$fs_file_max_calc" -lt 65536 ]; then
    fs_file_max_base="65536"
else
    fs_file_max_base=$fs_file_max_calc
fi
# 根据核心数调整上限
if [ "$cpu_cores" -gt 16 ] && [ "$mem_total_gb" -gt 8 ]; then # 核心数多且内存也较多
    fs_file_max_cap="2097152" # 2M
elif [ "$cpu_cores" -gt 8 ] || [ "$mem_total_gb" -gt 16 ]; then # 核心数或内存较高
    fs_file_max_cap="1572864" # 1.5M
else
    fs_file_max_cap="1048576" # 1M (默认上限)
fi
# 取基础值和上限中的较小者
if [ "$fs_file_max_base" -gt "$fs_file_max_cap" ]; then
    fs_file_max=$fs_file_max_cap
else
    fs_file_max=$fs_file_max_base
fi
echo "Calculated fs.file-max: $fs_file_max"

# 2. TCP 缓冲区 (tcp_rmem, tcp_wmem - min default max)
#    保持主要基于内存的分层设置
if [ "$mem_total_mb" -lt 1000 ]; then # < 1GB RAM
    echo "Applying settings for low memory system (< 1GB)"
    tcp_rmem="4096 87380 1048576"
    tcp_wmem="4096 16384 1048576"
elif [ "$mem_total_mb" -lt 4000 ]; then # 1GB - 4GB RAM
    echo "Applying settings for medium memory system (1GB-4GB)"
    tcp_rmem="8192 131072 4194304"
    tcp_wmem="4096 65536 4194304"
elif [ "$mem_total_mb" -lt 8000 ]; then # 4GB - 8GB RAM
    echo "Applying settings for high memory system (4GB-8GB)"
    tcp_rmem="8192 262144 8388608"
    tcp_wmem="4096 131072 8388608"
else # > 8GB RAM
    echo "Applying settings for very high memory system (> 8GB)"
    tcp_rmem="8192 524288 16777216"
    tcp_wmem="4096 262144 16777216"
fi
echo "TCP Read Buffer (rmem): $tcp_rmem"
echo "TCP Write Buffer (wmem): $tcp_wmem"

# 3. 文件描述符限制 (limits.conf - nofile)
#    使其等于计算出的 fs.file-max
limit_nofile=$fs_file_max
echo "User limit 'nofile': $limit_nofile"

# 4. 连接队列大小 (somaxconn, tcp_max_syn_backlog)
#    根据核心数分层设置，设置上限
if [ "$cpu_cores" -lt 4 ]; then
    conn_backlog="4096"
elif [ "$cpu_cores" -lt 9 ]; then # 4-8 cores
    conn_backlog="8192"
elif [ "$cpu_cores" -lt 17 ]; then # 9-16 cores
    conn_backlog="16384"
else # > 16 cores
    conn_backlog="32768" # 设置一个实际的上限
fi
# 确保 tcp_max_syn_backlog 不超过 somaxconn (通常设为相等)
somaxconn=$conn_backlog
tcp_max_syn_backlog=$conn_backlog
echo "Connection backlog (somaxconn/tcp_max_syn_backlog): $conn_backlog"

# --- 应用配置 ---

echo "Applying system resource limits (limits.conf)..."
# nproc 保持固定，nofile 使用计算值
cat >/etc/security/limits.conf<<EOF || error_exit "Failed to write to /etc/security/limits.conf."
# Settings applied by tcp-window.sh script (Enhanced Adaptive Version)
# Dynamically adjusted based on system resources:
# Memory: ${mem_total_mb} MB, CPU Cores: $cpu_cores

# Increased limits for high-performance services
* soft     nproc          655360    # Soft limit - process count (fixed)
* hard     nproc          655360    # Hard limit - process count (fixed)
* soft     nofile         $limit_nofile    # Soft limit - file descriptors (adjusted)
* hard     nofile         $limit_nofile    # Hard limit - file descriptors (adjusted)

root soft     nproc          655360
root hard     nproc          655360
root soft     nofile         $limit_nofile
root hard     nofile         $limit_nofile
EOF

# 确保PAM模块在会话中应用限制设置 (逻辑同前)
PAM_COMMON_SESSION="/etc/pam.d/common-session"
PAM_LIMITS_LINE="session required pam_limits.so"
if [ -f "$PAM_COMMON_SESSION" ]; then
    if ! grep -qF "$PAM_LIMITS_LINE" "$PAM_COMMON_SESSION"; then
        echo "Adding '$PAM_LIMITS_LINE' to $PAM_COMMON_SESSION..."
        echo "$PAM_LIMITS_LINE" >> "$PAM_COMMON_SESSION" || error_exit "Failed to append to $PAM_COMMON_SESSION."
    fi
else
    echo "Warning: $PAM_COMMON_SESSION not found. Skipping PAM limits configuration." >&2
fi
# (省略 common-session-noninteractive 的类似检查)

# 设置systemd默认文件句柄限制
SYSTEMD_CONF="/etc/systemd/system.conf"
SYSTEMD_LIMIT_LINE="DefaultLimitNOFILE=$limit_nofile"
echo "Configuring systemd default file limits..."
sed -i '/^DefaultLimitNOFILE=/d' "$SYSTEMD_CONF" || error_exit "Failed to modify $SYSTEMD_CONF."
echo "$SYSTEMD_LIMIT_LINE" >> "$SYSTEMD_CONF" || error_exit "Failed to append to $SYSTEMD_CONF."

echo "Applying kernel network parameters (sysctl.conf)..."
# 配置内核网络参数
cat >/etc/sysctl.conf<<EOF || error_exit "Failed to write to /etc/sysctl.conf."
# Settings applied by tcp-window.sh script (Enhanced Adaptive Version)
# Dynamically adjusted based on system resources:
# Memory: ${mem_total_mb} MB, CPU Cores: $cpu_cores

# System File Descriptor Limit (Adjusted)
fs.file-max = $fs_file_max

# TCP Congestion Control Algorithm (Fixed - BBR recommended)
net.ipv4.tcp_congestion_control = bbr
# Corresponding Queue Discipline (Fixed - FQ recommended)
net.core.default_qdisc = fq

# TCP Slow Start After Idle (Fixed)
net.ipv4.tcp_slow_start_after_idle = 0

# TCP Receive Memory (Adjusted by RAM)
net.ipv4.tcp_rmem = $tcp_rmem
# TCP Send Memory (Adjusted by RAM)
net.ipv4.tcp_wmem = $tcp_wmem

# TCP Window Scaling (Fixed)
net.ipv4.tcp_adv_win_scale = -2
# TCP Not Sent Low Water Mark (Fixed)
net.ipv4.tcp_notsent_lowat = 131072

# TCP Connection Queue Sizes (Adjusted by CPU Cores)
net.core.somaxconn = $somaxconn
net.ipv4.tcp_max_syn_backlog = $tcp_max_syn_backlog

# Other common optimizations (Fixed, uncomment/adjust if needed)
net.ipv4.tcp_mtu_probing = 0 # 1 to enable
# net.ipv4.tcp_tw_reuse = 1 # Enable fast reuse of TIME_WAIT sockets (use with caution)
# net.ipv4.tcp_fin_timeout = 30 # Reduce TIME_WAIT duration (use with caution)
# net.netfilter.nf_conntrack_max = 1048576 # Increase connection tracking table size if needed
# net.nf_conntrack_max = 1048576 # Newer kernels

# Disable IPv6 if needed (Uncomment)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1
EOF

echo "Applying sysctl settings immediately..."
# 应用 sysctl 设置
sysctl -p || echo "Warning: Some sysctl settings might require a reboot to take full effect." >&2

echo "------------------------------------------------------------------------"
echo "System network and resource limits optimization applied."
echo "Values were ADAPTED based on system resources:"
echo "  - Memory: ${mem_total_mb} MB"
echo "  - CPU Cores: $cpu_cores"
echo "Applied settings include:"
echo "  - fs.file-max: $fs_file_max"
echo "  - nofile limit: $limit_nofile"
echo "  - somaxconn/tcp_max_syn_backlog: $conn_backlog"
echo "  - TCP buffer settings adjusted by RAM."
echo
echo "IMPORTANT: A system reboot is REQUIRED for all changes to take full effect,"
echo "especially the file descriptor limits and some sysctl parameters."
echo "Please review the applied settings in /etc/sysctl.conf and /etc/security/limits.conf."
echo "Reboot your system when convenient."
echo "------------------------------------------------------------------------"