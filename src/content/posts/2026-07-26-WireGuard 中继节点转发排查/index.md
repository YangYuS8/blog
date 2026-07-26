---
title: "WireGuard 中继节点转发排查"
urlSlug: 'wireguard-relay-peer-forwarding-fix'
published: 2026-07-26
description: '记录一次 WireGuard 星型组网排查：客户端与中继、OpenWrt 与中继都能互通，但客户端无法访问 OpenWrt。根因是中继节点遗留的同接口 FORWARD DROP 规则。'
image: ''
author: ""
tags: ["WireGuard", "OpenWrt", "iptables", "UFW", "网络与代理", "故障排查", "实战记录"]
category: "网络与代理"
draft: false
lang: 'zh_CN'
---

这次网络故障的表现很怪：VPS 能 ping 通家里的 OpenWrt，OpenWrt 也能 ping 通 VPS；我的 Fedora 电脑同样能 ping 通 VPS，但就是 ping 不通 OpenWrt。

最后发现不是 WireGuard 握手、路由或 OpenWrt 本身的问题，而是 VPS 上一条历史遗留的转发规则把 **WireGuard peer 之间的流量**直接丢掉了。删掉旧规则、改成显式允许同接口转发后，问题解决。

这篇把排查过程写下来。这个场景适合一个 VPS 作为 WireGuard 中继，多个客户端通过同一个隧道网段互访的组网。

## 环境

拓扑如下：

```text
Fedora 电脑
10.0.0.3
    │
    │ WireGuard
    ▼
VPS 中继
10.0.0.1
wg-nesoriel
    │
    │ WireGuard
    ▼
家中 OpenWrt
10.0.0.20
```

VPS 运行 Ubuntu 22.04，WireGuard 接口名为 `wg-nesoriel`，监听 UDP `51820`。WireGuard 配置由宿主机的 `wg-quick@wg-nesoriel.service` 启动，WGDashboard 容器只负责管理配置和 peer。

客户端配置中，Fedora 到 VPS 的 peer 使用：

```ini
[Peer]
AllowedIPs = 10.0.0.0/24
Endpoint = <VPS 公网地址>:51820
PersistentKeepalive = 21
```

这意味着访问 `10.0.0.0/24` 的流量会进入 WireGuard 隧道。

## 现象

先分别测试三个节点：

```bash
# Fedora 电脑
ping -c 2 10.0.0.1
ping -c 2 10.0.0.20

# VPS
ping -c 2 10.0.0.20

# OpenWrt
ping -c 2 10.0.0.1
```

当时结果是：

```text
Fedora → VPS：通
VPS → OpenWrt：通
OpenWrt → VPS：通
Fedora → OpenWrt：不通
```

Fedora 上的路由是正确的：

```bash
ip route get 10.0.0.20
```

输出类似：

```text
10.0.0.20 dev wg-nesoriel src 10.0.0.3
```

再看 `tracepath`：

```bash
tracepath -n -m 5 10.0.0.20
```

第一跳能到 VPS 的 `10.0.0.1`，后续没有响应。这说明数据已经进入隧道并到达中继，问题应该在 VPS 转发路径或 OpenWrt 回程。

## 排查过程

### 确认 VPS 知道两个 peer 的去向

在 VPS 上查看 WireGuard 运行态：

```bash
sudo wg show wg-nesoriel
```

关键是确认两个 peer 都存在，并且 `AllowedIPs` 没有重叠：

```text
Fedora peer:   10.0.0.3/32
OpenWrt peer:  10.0.0.20/32
```

这一步决定 WireGuard 是否知道该把加密包交给哪个 peer。VPS 可以 ping 通 OpenWrt，说明 `10.0.0.20/32` 的 peer 映射和握手本身没问题。

### 确认内核开启 IPv4 转发

```bash
sysctl net.ipv4.ip_forward
```

预期结果：

```text
net.ipv4.ip_forward = 1
```

如果这里是 `0`，VPS 即使能分别与两个 peer 通信，也不会替它们转发三层流量。可以临时开启：

```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

长期配置应写到 `/etc/sysctl.d/` 或发行版已有的网络配置中，再用 `sysctl --system` 加载。

本次故障里，IPv4 转发已经开启，所以继续检查防火墙规则。

### 检查 FORWARD 链，而不只看 UFW 列表

VPS 上执行：

```bash
sudo iptables-save | grep -E 'wg-nesoriel|FORWARD|10\.0\.0\.'
```

发现了一条旧规则：

```text
-A FORWARD -i wg-nesoriel -o wg-nesoriel -j DROP
```

它的含义很直接：所有从 `wg-nesoriel` 进入、又需要从 `wg-nesoriel` 发出的包都被丢弃。

Fedora 到 OpenWrt 的流量正好符合这个条件：

```text
Fedora peer
  → VPS wg-nesoriel
  → VPS FORWARD
  → VPS wg-nesoriel
  → OpenWrt peer
```

因此 VPS 自己 ping OpenWrt 正常：本机发出的包走 `OUTPUT`，不经过 `FORWARD`。而客户端 peer 到另一个 peer 的包必经 `FORWARD`，所以失败。

这也是这个问题容易拖很久的原因：只做“客户端到服务器”和“服务器到客户端”的连通性测试，无法覆盖 peer-to-peer 转发路径。

## 根因

WireGuard 服务端的旧配置里曾经有下面的规则：

```ini
PostUp = ...; iptables -I FORWARD -i wg-nesoriel -o wg-nesoriel -j DROP
PreDown = ...; iptables -D FORWARD -i wg-nesoriel -o wg-nesoriel -j DROP
```

这类规则有时被用来禁止 VPN 客户端彼此访问。但当前需求是让 Fedora、OpenWrt 等 peer 经 VPS 中继互通，它与现有组网目标相反。

UFW 中虽然已经允许了：

```text
Anywhere on wg-nesoriel ALLOW IN
51820/udp ALLOW IN
```

但这只解决了进入 VPS 的流量和 UDP 监听端口问题，不会覆盖被 `iptables` 明确 DROP 的同接口转发流量。

## 修复

修改前先备份 WireGuard 配置和当前规则：

```bash
stamp=$(date +%Y%m%d-%H%M%S)
backup="/root/wireguard-forward-fix-$stamp"

sudo mkdir -p "$backup"
sudo cp -a /etc/wireguard/wg-nesoriel.conf "$backup/"
sudo iptables-save > "$backup/iptables.rules"
```

先删除运行态中的旧 DROP：

```bash
sudo iptables -D FORWARD \
  -i wg-nesoriel -o wg-nesoriel -j DROP
```

然后允许新连接和已建立连接返回：

```bash
sudo iptables -I FORWARD 1 \
  -i wg-nesoriel -o wg-nesoriel \
  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

sudo iptables -I FORWARD 1 \
  -i wg-nesoriel -o wg-nesoriel \
  -m conntrack --ctstate NEW -j ACCEPT
```

不要只改运行态。`wg-quick` 重启后会重新执行 `PostUp`，旧规则可能回来。因此还要修改 `/etc/wireguard/wg-nesoriel.conf`：

```ini
[Interface]
PostUp = iptables -t nat -I POSTROUTING 1 -s 10.0.0.1/24 -o eth0 -j MASQUERADE; iptables -I FORWARD 1 -i wg-nesoriel -o wg-nesoriel -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT; iptables -I FORWARD 1 -i wg-nesoriel -o wg-nesoriel -m conntrack --ctstate NEW -j ACCEPT
PreDown = iptables -t nat -D POSTROUTING -s 10.0.0.1/24 -o eth0 -j MASQUERADE; iptables -D FORWARD -i wg-nesoriel -o wg-nesoriel -m conntrack --ctstate NEW -j ACCEPT; iptables -D FORWARD -i wg-nesoriel -o wg-nesoriel -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

这里的 NAT 规则沿用原服务端配置。是否需要 NAT 取决于目标网段和回程路由；本例中保留它是为了不改变已经工作的对外访问行为。对 peer 之间互访，关键变化是删除 DROP 并允许同接口转发。

> 如果服务器使用的是 nftables 原生规则、firewalld 或云防火墙，应该按实际防火墙栈调整，不要把 iptables 命令直接套过去。

## 验证

先确认 VPS 上的规则顺序和计数器：

```bash
sudo iptables -nvL FORWARD | grep wg-nesoriel
```

预期能看到：

```text
ACCEPT ... wg-nesoriel → wg-nesoriel ... ctstate NEW
ACCEPT ... wg-nesoriel → wg-nesoriel ... ctstate RELATED,ESTABLISHED
```

然后从 Fedora 测试：

```bash
ping -c 4 10.0.0.20
```

本次结果：

```text
4 packets transmitted, 4 received, 0% packet loss
rtt min/avg/max ≈ 47/48/50 ms
```

再确认服务和隧道状态：

```bash
sudo systemctl is-active wg-quick@wg-nesoriel.service
sudo wg show wg-nesoriel latest-handshakes
```

最后检查重启后的持久性。维护窗口内可以重启 WireGuard 服务后重复 ping；如果不方便中断现网，至少确认 `PostUp` 和 `PreDown` 中已经不再包含旧 DROP 规则，并把这项测试放进下次维护清单。

## 总结

WireGuard 中继节点要让 peer 相互访问，需要同时满足：

```text
客户端路由指向隧道
+ 服务端 peer AllowedIPs 不重叠
+ net.ipv4.ip_forward = 1
+ FORWARD 链允许 wg-nesoriel → wg-nesoriel
+ 目标 peer 的回程仍经 WireGuard
```

这次故障的关键不是 WireGuard 本身，而是一个与现有需求相反的旧防火墙规则。排查时不要只验证“每台机器能否 ping VPS”；还要直接验证 peer 到 peer 的路径，并查看中继节点的 `FORWARD` 链和规则计数器。

把接口名统一为 `wg-nesoriel` 后，配置、服务名、监控和排查命令也更容易对应，不会再被历史命名拖进额外变量。 
