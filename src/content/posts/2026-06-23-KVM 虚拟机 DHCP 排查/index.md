---
title: "KVM 虚拟机 DHCP 排查"
urlSlug: 'kvm-libvirt-ufw-dhcp-troubleshooting'
published: 2026-06-23
description: "记录 AlmaLinux 9.8 虚拟机接入 libvirt default 网络后无法获取 192.168.122.0/24 地址的排查过程，最终定位到宿主机 UFW 拦截 virbr0 上的 DHCP/DNS 流量。"
image: ''
author: ""
tags: ["KVM", "libvirt", "AlmaLinux", "UFW", "DHCP", "故障排查"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这次在本机装了一台 AlmaLinux 9.8 KVM 虚拟机，虚拟机网卡接在 libvirt 默认网络上，但没有拿到预期的 `192.168.122.0/24` 地址。

最后排下来，问题不在 AlmaLinux 本身，也不是 libvirt 的 `default` 网络没启动，而是宿主机上的 UFW 把来自 `virbr0` 的 DHCP/DNS 流量拦住了。

## 现象

虚拟机名是 `almalinux9`，期望它从 libvirt 默认 NAT 网络获取地址。

libvirt 默认网络一般长这样：

- 网桥：`virbr0`
- 网关：`192.168.122.1/24`
- DHCP 地址池：`192.168.122.2 - 192.168.122.254`

但虚拟机启动后，在宿主机上查不到租约：

```bash
virsh -c qemu:///system domifaddr almalinux9 --source lease
```

输出为空：

```text
名称   MAC 地址   协议   地址
--------------------------------
```

## 环境

宿主机环境：

```text
OS: CachyOS Linux
Kernel: 7.0.12-1-cachyos
虚拟化: KVM / QEMU / libvirt
虚拟机: AlmaLinux 9.8
```

宿主机网络里已经能看到 `virbr0`：

```bash
ip -br addr
```

关键输出：

```text
virbr0    UP    192.168.122.1/24
vnet4     UNKNOWN    fe80::fc54:ff:fefc:cda3/64
```

这说明 libvirt 的网桥已经存在，虚拟机网卡也已经挂到了宿主机侧的 `vnet4` 上。

## 检查 libvirt 默认网络

一开始直接执行 `virsh net-list --all`，结果没有看到任何网络。

原因是普通 `virsh` 默认可能连到会话连接，而这台虚拟机实际在系统连接里。后续命令要显式指定：

```bash
virsh -c qemu:///system net-list --all
```

输出：

```text
名称      状态   自动开始   持久
-----------------------------------
default   活动   是         是
```

继续看 `default` 网络配置：

```bash
virsh -c qemu:///system net-dumpxml default
```

关键配置如下：

```xml
<network connections='1'>
  <name>default</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
```

这一步可以确认：

- `default` 网络是活动状态
- `virbr0` 地址正确
- DHCP 地址池存在
- NAT 模式正常开启

## 检查虚拟机网卡

再看虚拟机接到哪里：

```bash
virsh -c qemu:///system domiflist almalinux9
```

输出：

```text
接口    类型      源        型号     MAC
---------------------------------------------------------
vnet4   network   default   virtio   52:54:00:fc:cd:a3
```

虚拟机 XML 里的网卡片段也正常：

```xml
<interface type='network'>
  <mac address='52:54:00:fc:cd:a3'/>
  <source network='default' bridge='virbr0'/>
  <target dev='vnet4'/>
  <model type='virtio'/>
</interface>
```

到这里，libvirt 侧的连接关系没有明显问题：

```text
almalinux9 -> vnet4 -> virbr0 -> default NAT network
```

## 检查租约与 ARP

继续查虚拟机地址：

```bash
virsh -c qemu:///system domifaddr almalinux9 --source lease
virsh -c qemu:///system domifaddr almalinux9 --source arp
```

两者都没有结果。

再看 libvirt dnsmasq 的租约文件：

```bash
sudo sed -n '1,120p' /var/lib/libvirt/dnsmasq/virbr0.status
```

当时也没有有效租约。

这说明问题不是“地址拿到了但 `virsh` 没显示”，而是虚拟机确实没有从 libvirt DHCP 成功拿到地址。

## 发现 UFW 拦截线索

查看最近的系统日志时，出现了 UFW 拦截 `virbr0` 流量的记录：

```bash
sudo journalctl --since '2 hours ago' --no-pager | grep -Ei 'dnsmasq|virbr0|dhcp|52:54:00:fc:cd:a3|almalinux'
```

关键日志类似这样：

```text
kernel: virbr0: port 1(vnet4) entered forwarding state
kernel: [UFW BLOCK] IN=virbr0 OUT= MAC= SRC=192.168.122.1 DST=224.0.0.252 PROTO=UDP SPT=5355 DPT=5355
```

虽然这条日志本身是 LLMNR 多播，不是 DHCP，但它说明一个事实：

**UFW 确实在处理并拦截 `virbr0` 上的入站流量。**

于是继续检查 UFW 状态：

```bash
sudo ufw status verbose
```

输出：

```text
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
```

这里最关键的是两点：

- incoming 默认拒绝
- routed 默认拒绝

对 libvirt NAT 网络来说，虚拟机 DHCP 请求会从 `virbr0` 进宿主机，虚拟机出网还需要转发/NAT。如果 UFW 没有相应规则，就很容易把 libvirt 默认网络打断。

继续看 UFW 规则计数器，可以看到 DHCP 端口被命中到默认丢弃路径：

```bash
sudo iptables-save -c | grep -Ei 'ufw|dpt:67|dpt:68|virbr0'
```

关键线索是 `udp dport 67` 已经有计数，并被送到 UFW 的默认 input policy：

```text
-A ufw-after-input -p udp -m udp --dport 67 -j ufw-skip-to-policy-input
-A ufw-skip-to-policy-input -j DROP
```

这基本就把根因锁定了：

**宿主机 UFW 没有允许 `virbr0` 上访问 libvirt dnsmasq 的 DHCP/DNS 流量。**

## 根因

根因是宿主机 UFW 与 libvirt 默认 NAT 网络的规则没有配合好。

libvirt 的 `default` 网络本身是正常的：

- `virbr0` 正常存在
- `dnsmasq` 监听了 DHCP
- 虚拟机网卡接到了 `default`
- 虚拟机 MAC 也能在 bridge FDB 里看到

但 UFW 默认拒绝 incoming/routed，而没有为 `virbr0` 放行 DHCP、DNS 和转发流量。

因此虚拟机发出的 DHCP 请求无法被宿主机上的 libvirt dnsmasq 正常处理，表现出来就是虚拟机拿不到 `192.168.122.0/24` 地址。

## 修复方式

针对 `virbr0` 添加最小范围的 UFW 规则。

允许虚拟机访问宿主机上的 DHCP：

```bash
sudo ufw allow in on virbr0 to any port 67 proto udp comment 'libvirt DHCP on virbr0'
```

允许虚拟机访问宿主机上的 DNS：

```bash
sudo ufw allow in on virbr0 to any port 53 comment 'libvirt DNS on virbr0'
```

允许 `virbr0` 通过当前宿主机上行网卡转发出网：

```bash
sudo ufw route allow in on virbr0 out on enp4s0f3u1u4 comment 'libvirt NAT via wired uplink'
sudo ufw route allow in on virbr0 out on wlan0 comment 'libvirt NAT via wifi uplink'
```

最后重载 UFW：

```bash
sudo ufw reload
```

重载后查看规则：

```bash
sudo ufw status verbose
```

关键结果：

```text
67/udp on virbr0    ALLOW IN    Anywhere    # libvirt DHCP on virbr0
53 on virbr0        ALLOW IN    Anywhere    # libvirt DNS on virbr0
Anywhere on enp4s0f3u1u4  ALLOW FWD  Anywhere on virbr0
Anywhere on wlan0         ALLOW FWD  Anywhere on virbr0
```

这里的 `enp4s0f3u1u4` 和 `wlan0` 是我当时宿主机的两个上行接口。你自己的机器上要按实际默认路由接口调整。

可以用下面命令确认当前默认出口：

```bash
ip route show default
```

## 触发虚拟机重新 DHCP

添加防火墙规则后，可以重启虚拟机，也可以只断开/接回虚拟机网卡来触发 DHCP。

这次我选择后者：

```bash
virsh -c qemu:///system domif-setlink almalinux9 52:54:00:fc:cd:a3 down
sleep 2
virsh -c qemu:///system domif-setlink almalinux9 52:54:00:fc:cd:a3 up
```

等待几秒后再查租约：

```bash
virsh -c qemu:///system domifaddr almalinux9 --source lease
```

虚拟机成功拿到地址：

```text
名称    MAC 地址            协议   地址
--------------------------------------------------------
vnet4   52:54:00:fc:cd:a3   ipv4   192.168.122.232/24
```

租约文件里也能看到记录：

```json
[
  {
    "ip-address": "192.168.122.232",
    "mac-address": "52:54:00:fc:cd:a3",
    "client-id": "01:52:54:00:fc:cd:a3"
  }
]
```

## 验证

从宿主机 ping 虚拟机：

```bash
ping -c 3 -W 2 192.168.122.232
```

结果正常：

```text
3 packets transmitted, 3 received, 0% packet loss
rtt min/avg/max/mdev = 0.244/0.327/0.400/0.064 ms
```

再看邻居表：

```bash
ip neigh show dev virbr0
```

能看到虚拟机 MAC：

```text
192.168.122.232 lladdr 52:54:00:fc:cd:a3 REACHABLE
```

UFW 规则计数器也证明新规则确实被命中：

```text
-A ufw-user-input -i virbr0 -p udp -m udp --dport 67 -j ACCEPT
-A ufw-user-input -i virbr0 -p tcp -m tcp --dport 53 -j ACCEPT
-A ufw-user-input -i virbr0 -p udp -m udp --dport 53 -j ACCEPT
-A ufw-user-forward -i virbr0 -o enp4s0f3u1u4 -j ACCEPT
```

libvirt 的 NAT 规则也已经有转发计数：

```text
ip saddr 192.168.122.0/24 iif "virbr0" counter packets 19 bytes 1444 accept
meta l4proto udp ip saddr 192.168.122.0/24 ip daddr != 192.168.122.0/24 counter packets 19 bytes 1444 masquerade
```

到这里，虚拟机 DHCP 和宿主到虚拟机连通性已经恢复。

## 关于 qemu-guest-agent

这次排查时，宿主机上查询 guest agent 返回：

```text
QEMU 客户机代理未连接
```

所以没有直接从宿主机执行虚拟机内部命令来验证外网访问。

这不影响本次 DHCP 问题的修复。`qemu-guest-agent` 更适合后续统一配置虚拟机时一起安装，例如通过 Ansible 批量做：

```bash
sudo dnf install -y qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

装好之后，宿主机可以这样验证：

```bash
virsh -c qemu:///system qemu-agent-command almalinux9 '{"execute":"guest-ping"}'
```

## 排查顺序总结

这类 KVM/libvirt 虚拟机拿不到 `192.168.122.0/24` 地址的问题，可以按这个顺序查：

1. 确认使用的是 `qemu:///system` 还是 session 连接
2. 检查 `virsh -c qemu:///system net-list --all`
3. 检查 `default` 网络 XML 里的 bridge、DHCP range
4. 检查虚拟机 `domiflist` 是否接到 `network default`
5. 检查 `domifaddr --source lease` 和 dnsmasq 租约文件
6. 检查宿主机防火墙，尤其是 UFW/firewalld 是否拦截 `virbr0`
7. 放行 `virbr0` 上的 DHCP/DNS 和必要转发
8. 重新触发虚拟机 DHCP
9. 用 `ping`、`ip neigh`、租约文件和防火墙计数器验证

这次最容易误判的点是：`virbr0` 存在、`default` 网络活动、虚拟机也接到了 `default`，看起来 libvirt 侧一切正常。

但只要宿主机防火墙拦住了 `virbr0` 的 DHCP 请求，虚拟机依旧拿不到地址。排查时不要只看 libvirt，也要把宿主机防火墙纳入链路里。
