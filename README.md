# 代理服务一键安装脚本集合

# 项目说明：
# 该项目提供多种代理服务的一键安装脚本，包括：
# 1. Shadowsocks-rust - 高性能的 Rust 实现版本的 Shadowsocks
# 2. V2ray + Nginx + WebSocket + TLS - 带 WebSocket 和 TLS 加密的 V2ray 代理
# 3. Reality - 不需要域名的代理解决方案
# 4. Hysteria2 - 另一种不需要域名的高性能代理

搭建 Shadowsocks-rust， V2ray+ Nginx + WebSocket 和 Reality, Hysteria2 代理脚本，支持 Debian、Ubuntu、Centos，并支持甲骨文ARM平台。

简单点讲，没域名的用户可以安装 Reality 和 hy2 代理，有域名的可以安装 V2ray+ Nginx + WebSocket 代理，各取所需。

# 安装命令 - 运行此命令将下载并执行主脚本
运行脚本：

```
wget https://raw.githubusercontent.com/yeahwu/v2ray-wss/main/tcp-wss.sh && bash tcp-wss.sh
```

**便宜VPS推荐：** https://hostalk.net/deals.html

![image](https://github.com/user-attachments/assets/76396d58-3fef-4028-8a5f-f8c9260c76e5)

# 支持的操作系统列表
已测试系统如下：

Debian 9, 10, 11, 12

Ubuntu 16.04, 18.04, 20.04, 22.04

CentOS 7

# 客户端配置文件位置
WSS客户端配置信息保存在：
`cat /usr/local/etc/v2ray/client.json`

Shadowsocks客户端配置信息：
`cat /etc/shadowsocks/config.json`

Reality客户端配置信息保存在：
`cat /usr/local/etc/xray/reclient.json`

Hysteria2客户端配置信息保存在：
`cat /etc/hysteria/hyclient.json`

# 卸载方法
卸载方法如下：
https://1024.day/d/1296

**提醒：连不上的朋友，建议先检查一下服务器自带防火墙有没有关闭？**