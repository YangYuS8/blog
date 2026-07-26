---
title: "WireGuard 访问家庭局域网的回程路由排查"
urlSlug: 'wireguard-home-lan-return-route-snat'
published: 2026-07-27
description: '记录一次经 VPS 中继访问家庭 LAN 的 WireGuard 排障：隧道与 OpenWrt 可达，但 PVE、媒体服务器不通。根因是 LAN 默认网关缺少 VPN 回程路由，最终以 OpenWrt 精确 SNAT 兼容修复。'
image: ''
author: ""
tags: ["WireGuard", "OpenWrt", "nftables", "路由", "故障排查", "实战记录"]
category: "网络与代理"
draft: false
lang: 'zh_CN'
---

这次的目标是让外出的 Fedora 电脑经 VPS WireGuard 中继访问家中 `192.168.3.0/24` 局域网。隧道地址和 OpenWrt 本身都能访问，但 PVE 与媒体服务器始终不通。

最终确认不是 WireGuard 握手、VPS 转发或 OpenWrt 的 `wg_nesoriel → lan` 防火墙规则有问题，而是 **LAN 设备的默认网关不是 OpenWrt，导致回复流量走错路径**。本文记录实际拓扑、排查证据、两种可行修复方案，以及最终使用的精确 SNAT 规则。

## 环境

网络拓扑如下：

```text
远程 Fedora
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
wg_nesoriel: 10.0.0.20
LAN:         192.168.3.20/24
    │
    ├── PVE：192.168.3.16
    ├── 媒体服务器：192.168.3.30
    └── 家庭 LAN 默认网关：192.168.3.1
```

关键前提：OpenWrt 的 LAN 地址是 `192.168.3.20`，但整个家庭网段设备的默认网关是 `192.168.3.1`。这决定了后面的回程路由问题。

WireGuard 服务端接口为 `wg-nesoriel`，OpenWrt 接口为 `wg_nesoriel`。VPS 是星型中继，允许 peer 之间同接口转发。

## 先配置到家庭 LAN 的路由

要让 VPN 客户端访问 OpenWrt 后面的 LAN，三层路由需要在三个位置一致。

### VPS：把家庭网段归属到 OpenWrt Peer

VPS 的 `/etc/wireguard/wg-nesoriel.conf` 中，OpenWrt Peer 配置为：

```ini
[Peer]
# OpenWrt
PublicKey = <OPENWRT_PUBLIC_KEY>
AllowedIPs = 10.0.0.20/32, 192.168.3.0/24
Endpoint = <OPENWRT_ENDPOINT>:<PORT>
```

`AllowedIPs` 在服务端不仅是访问限制，还是 WireGuard 的 cryptokey routing 表：发往 `192.168.3.0/24` 的加密包会被交给 OpenWrt Peer。

仅改 Peer 的 `AllowedIPs` 还不够。服务端内核也需要有到家庭网段的路由：

```bash
ip route replace 192.168.3.0/24 dev wg-nesoriel
```

为了持久化，将其写进接口生命周期：

```ini
[Interface]
PostUp = ip route replace 192.168.3.0/24 dev wg-nesoriel; <原有 PostUp 命令>
PreDown = ip route del 192.168.3.0/24 dev wg-nesoriel 2>/dev/null || true; <原有 PreDown 命令>
```

如果只改运行态，重启 WireGuard 后路由会消失；这种“暂时好了”的网络配置通常会在最不合适的时间重新坏掉。

修改后可无中断同步 Peer 配置：

```bash
sudo wg syncconf wg-nesoriel <(sudo wg-quick strip wg-nesoriel)
ip route get 192.168.3.20
```

预期路由应走 `wg-nesoriel`：

```text
192.168.3.20 dev wg-nesoriel src 10.0.0.1
```

### 远程 Fedora：将家庭网段送入隧道

Fedora 的 `/etc/wireguard/wg-nesoriel.conf` 中，VPS Peer 需要包含家庭 LAN：

```ini
[Peer]
PublicKey = <VPS_PUBLIC_KEY>
AllowedIPs = 10.0.0.0/24, 192.168.3.0/24
Endpoint = <VPS_PUBLIC_IP>:51820
PersistentKeepalive = 21
```

应用后验证：

```bash
ip route get 192.168.3.20
```

预期：

```text
192.168.3.20 dev wg-nesoriel src 10.0.0.3
```

### OpenWrt：允许 VPN 转发到 LAN

OpenWrt 中 `wg_nesoriel` 放在独立防火墙区域，至少需要：

```text
wg_nesoriel → lan
```

实际 UCI 形态类似：

```text
firewall.<wg-zone>.network='wg_nesoriel'
firewall.<forwarding>.src='wg_nesoriel'
firewall.<forwarding>.dest='lan'
```

这一步完成后，远程 Fedora 已可以 ping 通 OpenWrt 的 LAN 地址：

```bash
ping -c 4 192.168.3.20
```

但 PVE 和媒体服务器仍不通。

## 现象

远程 Fedora 的测试结果：

```text
10.0.0.1      VPS 中继：通
10.0.0.20     OpenWrt WireGuard 地址：通
192.168.3.20  OpenWrt LAN 地址：通
192.168.3.16  PVE：不通
192.168.3.30  媒体服务器：不通
```

路由判断没有问题：

```bash
ip route get 192.168.3.16
ip route get 192.168.3.30
```

两者均显示：

```text
192.168.3.x dev wg-nesoriel src 10.0.0.3
```

同时，OpenWrt 自己能与两台服务器互 ping：

```text
OpenWrt → 192.168.3.16：通
OpenWrt → 192.168.3.30：通
```

因此 LAN 二层连通性和服务器在线状态没有问题。

## 排查过程

### 确认 OpenWrt 防火墙确实转发了请求

查看 firewall4 的实际规则，`wg_nesoriel` zone 中已经存在：

```text
forward_wg_nesoriel {
    jump accept_to_lan
}
```

VPS 上的 `FORWARD` 规则计数器也在增长，且抓包确认请求经过中继并被发往 OpenWrt：

```text
10.0.0.3 > 192.168.3.16: ICMP echo request
10.0.0.3 > 192.168.3.30: ICMP echo request
```

这说明请求路径完整：

```text
Fedora → VPS → OpenWrt → LAN 服务器
```

但抓不到返回的 ICMP echo reply。此时继续重复检查 WireGuard 握手没有意义，问题已缩小到 LAN 主机的回程。

### 找到不对称路由

PVE 和媒体服务器所在的 `192.168.3.0/24` 网段，其默认网关是：

```text
192.168.3.1
```

而转发请求的 OpenWrt 是：

```text
192.168.3.20
```

当 PVE 收到：

```text
源地址：10.0.0.3
目的地址：192.168.3.16
```

它需要回复 `10.0.0.3`。但本机没有 `10.0.0.0/24` 的静态路由，只会把回复交给默认网关 `192.168.3.1`。

`192.168.3.1` 又不知道 VPN 网段应经 `192.168.3.20` 返回，于是包离开了正确路径。

```text
请求：10.0.0.3 → OpenWrt 192.168.3.20 → 192.168.3.16
回复：192.168.3.16 → 默认网关 192.168.3.1 → 丢失
```

这解释了为什么 OpenWrt 自己可达：发往它本机的流量不需要经过 LAN 设备的默认路由；而任何由它转发到 LAN 的流量都依赖目标设备的回程路径。

## 修复方案选择

### 方案一：在家庭主网关添加静态路由

这是最干净的三层路由方案。在 `192.168.3.1` 上增加：

```text
目标网段：10.0.0.0/24
下一跳：192.168.3.20
```

这样 LAN 设备发送给 `10.0.0.0/24` 的流量会正确回到 OpenWrt，再转入 WireGuard。

优点：

- LAN 服务器能看到真实的远程客户端地址，例如 `10.0.0.3`；
- 可基于真实源 IP 做审计与 ACL；
- 不需要 NAT。

缺点是需要控制并修改家庭主网关 `192.168.3.1`。若它是光猫、上级路由器或不便维护的设备，这个方案不一定可用。

### 方案二：OpenWrt 对 VPN → LAN 做精确 SNAT

当前环境选择此方案。OpenWrt 在向 LAN 发送 VPN 客户端流量时，将源地址改为自己的 LAN 地址 `192.168.3.20`：

```text
原始请求：10.0.0.3 → 192.168.3.16
SNAT 后：192.168.3.20 → 192.168.3.16
```

LAN 服务器回复 `192.168.3.20` 时，路由不再依赖上级网关，回复会直接回到 OpenWrt。连接跟踪再将回复还原并交还给 `10.0.0.3`。

### 为什么不能只给 WireGuard zone 开启 Masquerade

这是本次实际踩到的一个细节。

在 OpenWrt firewall4 中，为 `wg_nesoriel` zone 设置：

```text
option masq '1'
```

会生成与**流量离开 `wg_nesoriel`**方向有关的 NAT 行为；它不能表达“流量从 `wg_nesoriel` 进入、从 `br-lan` 离开时 SNAT”这个需求。直接使用 zone NAT 没有解决问题。

某些 UCI `config nat` 写法也无法使用 `dest` zone 指定此类定向 SNAT。因此使用一个加载在 firewall4 `inet fw4` 表上下文的 nftables 自定义链，表达式最明确，范围也最小。

## 最终修复

编辑 OpenWrt 的 `/etc/nftables.d/10-custom-filter-chains.nft`，追加：

```nft
# VPN clients arrive on wg_nesoriel; LAN hosts use 192.168.3.1 as their
# default gateway, so SNAT to this router keeps reply traffic symmetric.
chain user_vpn_lan_snat {
    type nat hook postrouting priority srcnat; policy accept;
    iifname "wg_nesoriel" oifname "br-lan" \
      ip saddr 10.0.0.0/24 ip daddr 192.168.3.0/24 \
      snat to 192.168.3.20 \
      comment "wg-nesoriel to LAN reply-path SNAT"
}
```

然后重载防火墙：

```sh
/etc/init.d/firewall restart
nft list chain inet fw4 user_vpn_lan_snat
```

预期可看到：

```text
iifname "wg_nesoriel" oifname "br-lan" \
  ip saddr 10.0.0.0/24 ip daddr 192.168.3.0/24 \
  snat ip to 192.168.3.20
```

这里需要注意：

- 规则限制了入口接口、出口接口、VPN 源网段和家庭目标网段；
- 没有把 OpenWrt 全局 NAT 化；
- firewall4 重启会重新加载 `/etc/nftables.d/*.nft`，因此规则能持久化；
- 如果 LAN 网桥名不是 `br-lan`、OpenWrt LAN 地址不是 `192.168.3.20`，必须替换为实际值。

修改前建议备份：

```sh
stamp=$(date +%Y%m%d-%H%M%S)
backup="/root/fw-vpn-lan-nft-snat-$stamp"
mkdir -p "$backup"
cp -a /etc/config/firewall "$backup/firewall.before"
cp -a /etc/nftables.d/10-custom-filter-chains.nft \
  "$backup/10-custom-filter-chains.nft.before"
```

回滚也很直接：删除新增链，恢复备份文件，再重启防火墙。

## 验证结果

从远程 Fedora 实测：

```bash
ping -c 4 192.168.3.16
ping -c 4 192.168.3.30
```

结果：

```text
PVE 192.168.3.16：4/4 收到，0% 丢包，平均约 49.5 ms
媒体服务器 192.168.3.30：4/4 收到，0% 丢包，平均约 49.5 ms
```

同时验证 TCP 服务：

```text
192.168.3.16:22   open
192.168.3.16:8006 open
192.168.3.30:22   open
```

PVE Web 管理页面可以通过下面地址访问：

```text
https://192.168.3.16:8006/
```

媒体服务器的 `80`、`443` 端口未开放或没有服务监听，这与 WireGuard 路由无关；SSH 已可达说明网络路径已经恢复。

## 总结

经 WireGuard 访问远端家庭 LAN 时，不能只验证：

```text
VPN 客户端 → VPS
VPS → OpenWrt
VPN 客户端 → OpenWrt
```

还必须验证最终 LAN 设备的回程路由。完整条件是：

```text
客户端路由指向 WireGuard
+ VPS 内核路由与 Peer AllowedIPs 指向 OpenWrt
+ VPS FORWARD 允许 wg-nesoriel → wg-nesoriel
+ OpenWrt 允许 wg_nesoriel → lan
+ LAN 设备能将回复送回 OpenWrt 或主网关有 VPN 回程路由
```

能修改主网关时，优先加静态路由 `10.0.0.0/24 via 192.168.3.20`。不能修改主网关时，对 `wg_nesoriel → br-lan` 使用精确 SNAT 是兼容性更强、影响范围更小的替代方案。

网络故障往往不是“隧道没通”，而是包在回家的路上被默认网关带偏了。把请求路径和回复路径分别验证，通常比盯着握手时间戳高效得多。
