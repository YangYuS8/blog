---
title: "Headscale 一次 DNS 误接管排错：Fedora 接入后延迟异常的定位与修复"
urlSlug: '20260506-02'
published: 2026-05-06
description: '记录一次 headscale 接入排错：Fedora 连上 tailscale/headscale 后访问普通网站延迟异常，最后定位到问题不在路由而在 DNS 被 headscale 全局接管，并通过关闭 override_local_dns 修复。'
image: ''
tags: ['headscale', 'tailscale', 'Fedora', 'DNS', '问题排查', 'FlClash']
category: '问题排查'
draft: false 
lang: 'zh_CN'
---

这次问题的表面现象很怪。

我在 Fedora 上接入自己的 headscale 之后，内网访问看起来没什么问题，但打开正常网站时，延迟突然变高了，体验非常不对劲。

最开始我直觉会怀疑几件事：

- 是不是默认路由被 Tailscale 改了
- 是不是开了 exit node
- 是不是 FlClash 和 tailscale0 之间有流量绕路
- 是不是 headscale 本身下发了什么不该下发的网络配置

但最后排下来，真正的问题其实是：**DNS 被 headscale 接管了。**

## 先说结论

如果你也遇到下面这种情况：

- 接入 headscale 后普通网站变慢
- `ip route get` 看着没问题
- 但 `resolvectl status` 里看到 `tailscale0` 挂了 `100.100.100.100`
- 还出现了 `DNS Domain: xxx ~.`

那你要优先怀疑的不是路由，而是 **headscale 下发了全局 DNS**。

这篇就按我当时的排查顺序，把这个问题完整捋一遍。

## 症状是什么

我接入之后，普通网站访问延迟明显偏高。

于是我先查路由：

```bash
ip route get 1.1.1.1
ip route get 8.8.8.8
ip route get 223.5.5.5
```

当时输出的关键信息类似这样：

```bash
1.1.1.1 via 192.168.124.1 dev eno2 src 192.168.124.6
8.8.8.8 via 192.168.124.1 dev eno2 src 192.168.124.6
223.5.5.5 via 192.168.124.1 dev eno2 src 192.168.124.6
```

这说明一个重要事实：

**默认路由还在物理网卡 `eno2` 上，没有被 tailscale 接管。**

也就是说，这时候问题大概率不在三层转发路径上。

## 为什么我没有继续在“路由”上浪费时间

很多人一看到“连上 VPN 后网站变慢”，第一反应就是：

> 默认路由是不是被改了？

这个怀疑没错，但你要先用命令把它排掉。

当 `ip route get` 已经明确告诉你公网目标还是从本地网关走时，说明：

- 不是 exit node 导致所有流量穿隧道
- 不是 `tailscale0` 抢了默认路由
- 至少大部分“访问变慢”的原因，不在 IP 层转发本身

这时再继续死盯路由，基本就是浪费时间了。

## 真正暴露问题的是 `resolvectl status`

接着我查了 DNS 状态：

```bash
resolvectl status
```

当时最关键的一段是这个：

```text
Link 5 (tailscale0)
    Current Scopes: DNS
         Protocols: +DefaultRoute -LLMNR -mDNS -DNSOverTLS DNSSEC=no/unsupported
Current DNS Server: 100.100.100.100
       DNS Servers: 100.100.100.100 fd7a:115c:a1e0::53
        DNS Domain: vpn.geneden.top ~.
     Default Route: yes
```

这里最该警惕的是两点：

1. `Current DNS Server: 100.100.100.100`
2. `DNS Domain: vpn.geneden.top ~.`

尤其是最后这个 `~.`。

## `~.` 到底意味着什么

在 `systemd-resolved` 这套语义里，`~.` 基本可以理解成：

**把所有域名查询都优先交给这个链路处理。**

也就是说，不只是 `vpn.geneden.top` 这种 Tailnet 内部域名，连你访问普通公网网站时的 DNS 解析，也可能被引到 `tailscale0` 这一侧。

这就会带来两个直接后果：

- 普通网站解析不再走你本地网络原本的 DNS
- 每次访问都可能多绕一层 Tailscale / headscale 相关的 DNS 路径

所以你看到的“网站能打开，但延迟莫名变高”，就很合理了。

## 这个问题为什么容易误判成代理或者 FlClash

因为现象太像“代理绕路”了。

尤其如果你本机还在跑 FlClash，一开始很容易怀疑：

- 是不是 Tailscale 被代理了
- 是不是某些流量没有正确直连
- 是不是 tun / 系统代理和 tailscale0 打架了

但这次不是。

这次真正被改的是 **DNS 解析路径**，不是浏览器请求本身的转发路径。

所以即便你把 Tailscale 从 FlClash 的代理策略里排除掉了，只要 DNS 还是被 `tailscale0` 接管，慢的问题依旧可能存在。

## 根因：headscale 服务端下发了全局 DNS

到这里，根因就比较明确了。

headscale 这一侧下发了 DNS 配置，客户端接入后接受了这些配置，于是 Fedora 上的 `tailscale0` 获得了：

- `100.100.100.100`
- Tailnet 域名
- 以及最关键的 `~.`

这说明它不是只帮你解析内网名字，而是**有机会接管整机的默认 DNS 查询**。

## 服务端应该怎么改

如果你的目标是：

- 保留 MagicDNS
- 还能解析 Tailnet 内部域名
- 但不要强制接管客户端本地 DNS

那么 headscale 的 `config.yaml` 里，DNS 部分应该改成下面这样：

```yaml
dns:
  magic_dns: true
  base_domain: vpn.geneden.top
  override_local_dns: false
```

核心只有一条：

```yaml
override_local_dns: false
```

它的作用是：

**不要要求客户端用 headscale 下发的 DNS 覆盖本地 DNS。**

### 如果你原来写过 `nameservers.global`

有些配置里可能还会写：

```yaml
dns:
  magic_dns: true
  base_domain: vpn.geneden.top
  override_local_dns: true
  nameservers:
    global:
      - 1.1.1.1
      - 8.8.8.8
```

或者你为了“不要改 DNS”，尝试过这样清空：

```yaml
nameservers:
  global: []
```

这时要注意一个版本相关的问题。

## 我遇到的第二个坑：`global: []` 直接报错

我后面还遇到了一条很典型的报错：

```text
loading configuration: Fatal config error: dns.nameservers.global must be set when dns.override_local_dns is true
```

这个报错的意思很直接：

- 你还开着 `override_local_dns: true`
- 但你把 `nameservers.global` 清空了

这两件事在当前 headscale 版本里是冲突的。

所以正确修法不是只改 `global: []`，而是把这项也一起关掉：

```yaml
dns:
  magic_dns: true
  base_domain: vpn.geneden.top
  override_local_dns: false
```

如果你非要保留 `nameservers:` 结构，也可以写成：

```yaml
dns:
  magic_dns: true
  base_domain: vpn.geneden.top
  override_local_dns: false
  nameservers:
    global: []
```

但如果当前版本还是不喜欢空数组，那就直接删掉 `nameservers` 这段，保留最上面那份最简配置就行。

## 改完服务端以后要做什么

改完 headscale 配置后，重启服务。

如果你是 Docker：

```bash
docker restart headscale
```

如果你是 Compose：

```bash
docker compose restart headscale
```

然后最好看一下日志确认配置已经正常加载：

```bash
docker logs --tail=100 headscale
```

### 这一步的作用

这一步不是走形式。

因为你前面如果刚好踩到了 `override_local_dns: true` 和 `global: []` 的冲突，headscale 是有可能直接起不来的。

所以改完以后，一定要看日志确认不是“配置文件保存成功了，但服务根本没起来”。

## 客户端也要顺手修一下

服务端改完后，已经接入的 Fedora 客户端最好再手动纠正一次。

我建议执行：

```bash
sudo tailscale set --accept-dns=false --accept-routes=false --exit-node=
sudo resolvectl flush-caches
```

如果你只想处理 DNS，也至少把这条做掉：

```bash
sudo tailscale set --accept-dns=false
```

### 这一步的作用

这里主要是两个目的：

- `--accept-dns=false`：不接受 headscale / tailscale 下发的 DNS
- `--accept-routes=false`：顺手避免意外接受子网路由
- `--exit-node=`：清掉可能残留的出口节点配置
- `resolvectl flush-caches`：把旧缓存也一起清掉

这样客户端状态会更干净，不会因为旧缓存让你误判“怎么改完还没生效”。

## 怎么验证已经修好

还是先看：

```bash
resolvectl status
```

正常情况下，`tailscale0` 下面就不应该再出现这种组合：

```text
Current DNS Server: 100.100.100.100
DNS Domain: vpn.geneden.top ~.
Default Route: yes
```

尤其是：

```text
~.
```

如果这个还在，就说明“全局 DNS 接管”这件事还没有真正消失。

另外再看一下公网目标路由，确认还是本地出口：

```bash
ip route get 1.1.1.1
ip route get 8.8.8.8
```

如果：

- 路由还是本地网关
- `tailscale0` 不再带 `~.`
- 普通网站访问延迟恢复正常

那这次问题基本就算彻底结束了。

## 以后怎么避免新设备再被自动改 DNS

这件事最好两边都做。

### 做法 1：服务端默认不覆盖本地 DNS

也就是前面那份配置：

```yaml
dns:
  magic_dns: true
  base_domain: vpn.geneden.top
  override_local_dns: false
```

这样后面新设备加入时，服务端就不会再主动强推“把整机 DNS 交给我”。

### 做法 2：客户端接入时显式拒绝 DNS

以后新设备接入时，命令尽量固定成这种形式：

```bash
sudo tailscale up \
  --login-server=https://your-headscale.example.com \
  --accept-dns=false
```

如果你用的是 auth key，也同样把这个参数带上。

### 这两层为什么都要做

因为只改一边还不够稳。

- 只改服务端：旧客户端可能还保留着旧状态
- 只改客户端：以后换设备时还是容易忘

两边都处理，才比较省心。

## 一个顺手记下的小坑：别急着进容器里改

这次前面还有个很容易让人分心的小坑。

我一开始想直接进 headscale 容器里看东西，结果报错：

```text
OCI runtime exec failed: exec failed: unable to start container process: exec: "/bin/sh": stat /bin/sh: no such file or directory
```

这类报错通常说明镜像非常精简，里面根本没有 `/bin/sh` 或 `/bin/bash`。

这时候不要把精力浪费在“为什么容器里没有 shell”上。

更实际的做法是：

- 先确认配置文件是怎么挂载进去的
- 直接编辑宿主机上的 `config.yaml`
- 然后重启容器并看日志

很多 headscale 镜像本来就不是拿来给你交互式排障的。

## 这次排错最值得记住的点

这次真正有价值的不是某一条命令，而是排查顺序。

我最后觉得最稳的一套判断逻辑是：

1. 先用 `ip route get` 排除默认路由问题
2. 再用 `resolvectl status` 查 DNS 有没有被 `tailscale0` 接管
3. 看到 `100.100.100.100` 和 `~.`` 后，优先回 headscale 服务端配置排查
4. 用 `override_local_dns: false` 修正默认行为
5. 客户端再用 `tailscale set --accept-dns=false` 兜底

其中最关键的一点是：

**“网站访问慢”不一定是流量真的走错路了，也可能只是 DNS 先走错了。**

## 最终可用配置

如果你和我一样，希望：

- 保留 MagicDNS
- 保留 Tailnet 内部域名解析
- 不要强制改客户端系统 DNS

那我最后建议保留这份最简配置：

```yaml
dns:
  magic_dns: true
  base_domain: vpn.geneden.top
  override_local_dns: false
```

客户端接入时，再补一层：

```bash
sudo tailscale up --accept-dns=false
```

## 结尾

这次问题看起来像是“网络慢”，实际上是一次很典型的 **DNS 误接管**。

路由没错，代理也不一定有问题，但只要 `tailscale0` 拿到了 `~.`，普通网站的解析路径就可能被整个改掉。

以后如果你在 headscale / tailscale 环境里也遇到：

- 网站能开，但延迟明显异常
- 公网路由看起来正常
- `tailscale0` 下挂着 `100.100.100.100`
- `resolvectl status` 里还有 `~.`

那就别再绕去查别的了，先查 DNS。