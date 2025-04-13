##!/bin/sh
# 问题反馈链接: https://1024.day
# 脚本名称: tcp-window.sh
# 脚本功能: 优化系统网络参数，提高代理服务性能
# 创建日期: 2025年4月13日
# 支持系统: Debian, Ubuntu, CentOS 7及以上
# 特点: 调整系统资源限制和TCP参数，优化网络性能

# 引入共享库，使用点号引入脚本，这样可以在当前shell环境中执行
. ./common.sh

# 检查root权限
check_root

# 修改系统资源限制，提高最大进程数和最大文件句柄数
# 这对于处理大量并发连接的代理服务非常重要
cat >/etc/security/limits.conf<<EOF
# 设置所有用户的进程数和文件句柄数限制
* soft     nproc          655360    # 软限制-进程数
* hard     nproc          655360    # 硬限制-进程数
* soft     nofile         655360    # 软限制-文件句柄数
* hard     nofile         655360    # 硬限制-文件句柄数

# 设置root用户的进程数和文件句柄数限制
root soft     nproc          655360
root hard     nproc          655360
root soft     nofile         655360
root hard     nofile         655360

# 设置bro用户的进程数和文件句柄数限制(如果存在的话)
bro soft     nproc          655360
bro hard     nproc          655360
bro soft     nofile         655360
bro hard     nofile         655360
EOF

# 确保PAM模块在会话中应用限制设置
# 这行配置确保每次登录会话都会加载limits.conf中的限制
echo "session required pam_limits.so" >> /etc/pam.d/common-session

# 为非交互式会话也应用相同的限制设置
echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive

# 设置systemd默认文件句柄限制
# 这确保由systemd管理的服务也遵循文件句柄限制
echo "DefaultLimitNOFILE=655360" >> /etc/systemd/system.conf

# 配置内核网络参数，优化TCP性能
cat >/etc/sysctl.conf<<EOF
# 设置系统最大文件句柄数
fs.file-max = 655360
# 启用BBR拥塞控制算法，提高网络吞吐量和减少延迟
net.ipv4.tcp_congestion_control = bbr
# 使用fq队列调度算法，改善数据包调度
net.core.default_qdisc = fq
# 禁用TCP慢启动，提高重新建立连接时的性能
net.ipv4.tcp_slow_start_after_idle = 0
# MTU探测设置(已注释)，可以优化数据包大小
#net.ipv4.tcp_mtu_probing = 1
# 设置TCP接收缓冲区大小 (最小值、默认值、最大值)，单位为字节
net.ipv4.tcp_rmem = 8192 262144 167772160
# 设置TCP发送缓冲区大小 (最小值、默认值、最大值)，单位为字节
net.ipv4.tcp_wmem = 4096 16384 83886080
# UDP缓冲区最小值设置(已注释)
#net.ipv4.udp_rmem_min = 8192
#net.ipv4.udp_wmem_min = 8192
# 调整TCP窗口缩放因子，影响窗口增长速率
net.ipv4.tcp_adv_win_scale = -2
# 设置未发送数据的低水位标记，优化内存使用
net.ipv4.tcp_notsent_lowat = 131072
# IPv6禁用设置(已注释)，如果需要可以取消注释禁用IPv6
#net.ipv6.conf.all.disable_ipv6 = 1
#net.ipv6.conf.default.disable_ipv6 = 1
#net.ipv6.conf.lo.disable_ipv6 = 1
EOF

# 清理安装脚本
rm tcp-window.sh

# 应用新设置并重启系统
# sleep 3 等待3秒后重启
# >/dev/null 2>&1 将所有输出重定向到/dev/null，隐藏重启信息
sleep 3 && reboot >/dev/null 2>&1