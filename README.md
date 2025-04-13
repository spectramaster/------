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
wget https://raw.githubusercontent.com/spectramaster/vpn/main/tcp-wss.sh && bash tcp-wss.sh
```

![image](https://github.com/user-attachments/assets/76396d58-3fef-4028-8a5f-f8c9260c76e5)

# 支持的操作系统列表
已测试系统如下：

1.Debian 9, 10, 11, 12

2.Ubuntu 16.04, 18.04, 20.04, 22.04

3.CentOS 7

# 客户端配置文件位置
WSS客户端配置信息保存在：
`cat /usr/local/etc/v2ray/client.json`

Shadowsocks客户端配置信息：
`cat /etc/shadowsocks/config.json`

Reality客户端配置信息保存在：
`cat /usr/local/etc/xray/reclient.json`

Hysteria2客户端配置信息保存在：
`cat /etc/hysteria/hyclient.json`

# 相比原版的更新内容
1.创建了共享库 common.sh：

a.包含了常用功能函数，如权限检查、IP获取、随机参数生成等

b.每个函数都有详细的注释，说明其用途、参数和返回值

c.设计为可在多种脚本中通用，提高代码复用性

2.修改所有原始脚本：

a.每个脚本都引入共享库

b.替换重复代码为共享库中的函数调用

c.保持原有功能和逻辑不变

3.增加了详细注释：

a.文件头部包含脚本名称、功能、创建日期和系统要求

b.每个函数都有完整的功能说明

c.每个配置块和重要代码段都有行内注释

d.复杂设置添加了解释性注释，如端口、协议参数等

4.代码结构优化：

a.使用一致的编码风格和命名规范

b.函数按逻辑顺序排列

c.主执行流程清晰可辨

# 卸载方法
卸载可以使用这篇帖子中的方法：https://1024.day/d/1296

# 源代码来源
本仓库源自https://github.com/yeahwu/v2ray-wss

# 重要！
1.连不上的朋友，建议先检查一下服务器自带防火墙有没有关闭？

2.所有修改均由人工智能生成，仅供学习参考，请谨慎使用脚本