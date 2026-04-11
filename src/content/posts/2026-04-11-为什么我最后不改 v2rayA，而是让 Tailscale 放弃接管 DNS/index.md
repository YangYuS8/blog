---
title: "为什么我最后不改 v2rayA，而是让 Tailscale 放弃接管 DNS"
urlSlug: '20260411-01'
published: 2026-04-11
description: '记录一次在 PVE 宿主机上排查 v2rayA 与 Tailscale 冲突的过程：表面上像是 Tailscale 掉线，实际根因是 DNS 接管冲突。最后我没有继续硬改 v2rayA，而是直接让 Tailscale 放弃接管系统 DNS。'
image: ''
tags: ['Tailscale', 'v2rayA', 'PVE', 'Linux', 'DNS', '问题排查']
category: '问题排查'
draft: false 
lang: 'zh_CN'
---

这次问题一开始看起来像是 Tailscale 自己抽风了。

PVE 宿主机在局域网里还能正常访问，SSH 到 `192.168.3.16` 没问题，但它原本的 Tailscale 地址 `100.64.0.1` 却死活连不上。

如果只看表面现象，很容易第一反应就是：

- Tailscale 掉线了
- headscale 挂了
- 或者这台 PVE 的网络炸了

但真正往下查以后，问题并不是“组网坏了”，而是**DNS 接管冲突**。

## 先把现象分开看

我先做的第一步，不是直接改配置，而是先确认到底是哪一层坏了。

结果很快就把范围缩小了：

- `192.168.3.16:22` 可以正常连接
- `100.64.0.1:22` 不通
- `tailscaled` 服务本身是 active
- 但 `tailscale status --json` 里是 `NoState`

这说明一件事：

**宿主机本地网络没坏，真正坏的是 Tailscale 这条链路。**

## 日志真正指向的是控制面超时

继续看 `tailscaled` 日志后，问题越来越像不是客户端自己炸了，而是它连不上控制面：

```text
fetch control key: Get "https://headscale.geneden.top/key?v=133": context deadline exceeded
```

更关键的是，它还会不断尝试各种 `bootstrapDNS(...)`，然后超时。

看到这里，最容易先怀疑的是：

- headscale 服务端是不是坏了
- 这台机器的 DNS 是不是有问题
- 这台 PVE 的外网是不是不通

但继续往下查，情况又不完全支持这些猜测。

## headscale 本身并没有坏

后面确认下来，这个 headscale 实例并不是全局坏掉了，因为你的其他节点都还能正常在线。

这很关键。

它说明问题不是“控制面全挂”，而是：

> **只有这台 PVE 到控制面的访问链路有问题。**

这时候，注意力就不该继续放在 headscale 本身，而应该回到这台主机的网络环境上。

## 真正可疑的是 v2rayA

继续看这台 PVE 的系统配置后，最醒目的线索其实是：

```text
# v2rayA DNS hijack
nameserver 127.2.0.17
nameserver 119.29.29.29
```

而且本机上还跑着：

- `v2raya.service`
- 本地 DNS 监听
- 透明代理相关 iptables 规则

这时候问题的形状就开始清楚了。

不是 Tailscale 单纯掉线，而是：

- v2rayA 正在接管系统 DNS
- Tailscale 也想改系统 DNS
- 两边在 `/etc/resolv.conf` 和 DNS 处理链路上互相打架
- 最后把 Tailscale 自己的控制面访问拖死了

## 我一开始也尝试过从 v2rayA 这边修

当时并不是没有想过直接修 v2rayA。

我也试过往这几个方向去改：

- 查 v2rayA 配置文件
- 看 DNS hijack 相关设置
- 调整路由排除规则
- 尝试让 `headscale.geneden.top` 和 `100.64.0.0/10` 不再被它处理

这些尝试不是完全没价值，但有个现实问题：

**v2rayA 这类工具一旦已经接管系统 DNS，它的行为常常不只来自一个配置文件。**

你改了一个地方，它可能还有运行时逻辑、服务参数，甚至管理面板选项继续把 `/etc/resolv.conf` 改回去。

也就是说，继续硬改 v2rayA，不是不行，但会变得越来越像在和一个“全局接管器”拔河。

## 真正让我下决心换思路的证据

后面有一步非常关键：

我把 `v2rayA` 停掉，再重启 `tailscaled`，结果 Tailscale 立刻恢复了。

这一步几乎是实锤。

因为它说明：

- headscale 没坏
- Tailscale 客户端也没真正坏
- 宿主机网络没坏
- 真正的问题就是 **v2rayA 和 Tailscale 在 DNS 接管层面的冲突**

到这里，思路就该变了。

## 为什么我最后不继续改 v2rayA

如果目标是“两个都能共存”，最自然的第一反应通常是继续改 v2rayA，让它别碰 Tailscale。

但我最后没有这么选，原因很实际：

### 1）v2rayA 这套接管逻辑比较重

它不只是一个单纯代理开关，而是：

- DNS hijack
- 本地 DNS 监听
- 透明代理
- iptables 重定向
- 运行时回写 `/etc/resolv.conf`

这种东西要改到“完全不干扰 Tailscale”，你很容易越改越深。

### 2）我的真实需求没那么复杂

这台 PVE 上，我真正需要的是：

- Tailscale 节点能在线
- `100.64.0.1` 能访问
- tailnet 互联正常

我并不是真的很需要：

- 让这台宿主机必须使用 MagicDNS
- 让 Tailscale 来管理系统级 DNS

既然如此，最省事的方向就很明显了：

> **不是让 v2rayA 让路，而是直接让 Tailscale 放弃接管系统 DNS。**

## 最后的解决方案

最终我在这台 PVE 上执行的是：

```bash
tailscale up --accept-dns=false --login-server=https://headscale.geneden.top
```

然后重启 `tailscaled` 再确认一次状态。

这个动作的意义就是：

- Tailscale 继续加入 tailnet
- 继续保留 `100.64.x.x` 地址
- 继续正常互联
- 但不再试图修改系统 DNS

换句话说，它保留“组网功能”，放弃“DNS 管理权”。

## 结果怎么样

结果非常干净。

后面再看状态：

- `BackendState: Running`
- `TailscaleIPs: 100.64.0.1`
- 节点恢复在线
- 不再有之前那种控制面超时导致的掉线问题

更重要的是，日志里能明确看到：

- Tailscale 的 `dns=false`
- 不再试图接管系统 DNS

这就说明，最关键的冲突点已经被拆开了。

## 这样做的代价是什么

代价当然有，但在这个场景下完全可以接受。

你会失去的是：

- Tailscale 对这台主机的系统级 DNS 接管
- 某些 MagicDNS 的自动解析便利

但你保留下来的，是更重要的东西：

- tailnet 节点在线
- Tailscale IP 可访问
- 宿主机和其他节点互通
- 不再和 v2rayA 在 DNS 层反复打架

对 PVE 宿主机来说，这个取舍非常划算。

## 这次排查里最重要的一点

如果要把这次经验总结成一句话，我会写成：

**当两个“都想接管系统 DNS”的工具放在同一台机器上时，最稳的解决方式往往不是让它们都继续管，而是明确地只保留一个。**

这次我最后选择保留的是：

- v2rayA 管系统 DNS
- Tailscale 只管组网

而不是反过来。

## 写在最后

这次问题表面上是“PVE 上 Tailscale 掉线”，但真正的根因并不在 Tailscale 本身。

它更像是一个典型的“两个系统级工具都想改同一层”的冲突：

- 一个想接管 DNS
- 另一个也想接管 DNS
- 最后谁都不舒服

如果你的真实需求只是让 Tailscale 继续提供 tailnet 连接，而不是强依赖 MagicDNS，那我会很推荐直接像这次这样处理：

**让 Tailscale 放弃接管 DNS，问题通常会比你继续和代理工具硬碰硬来得简单得多。**
