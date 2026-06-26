---
title: "OpenWrt 旁路代理网关部署"
urlSlug: 'openwrt-sidecar-proxy-gateway'
published: 2026-06-26
description: '记录在 PVE 中部署 OpenWrt x86_64 作为旁路代理网关的过程：关闭 DHCP、导入 UEFI 镜像、解决 Secure Boot 问题、安装 OpenClash，并为 Docker 服务机提供显式代理。'
image: ''
author: ""
tags: ["OpenWrt", "PVE", "OpenClash", "Docker", "网络代理", "实战记录", "故障排查"]
category: "网络与代理"
draft: false
lang: 'zh_CN'
---
上一篇整理 PVE 服务分层时，我新建了 `infra-docker-01`，准备把 Docker 和业务容器逐步从 PVE 宿主机迁出来。

但 Docker 装好后，第一步测试就卡住了：Docker Hub 访问超时，`hello-world` 拉不下来。

这篇记录第二个基础节点：在 PVE 中部署 OpenWrt x86_64 虚拟机 `net-gateway-01`，先把它作为旁路代理网关，为 `infra-docker-01` 提供显式 HTTP(S) 代理。

这里要先说清楚：当前它不是主路由，也不接管 DHCP，只是一个独立的代理节点。

## 目标

当前网络中的关键节点：

```text
PVE 本体：192.168.3.16
net-gateway-01：192.168.3.20
infra-docker-01：192.168.3.30
主路由：192.168.3.1
```

这一阶段的目标很简单：

```text
infra-docker-01
    ↓ Docker daemon 显式代理
net-gateway-01:7890
    ↓ OpenClash / Mihomo
外部 Docker Hub
```

同时，也要明确这一阶段不做什么：

```text
不作为主路由
不接管 DHCP
不作为全局默认网关
不启用全网透明代理
不启用 DNS 劫持
```

先让显式代理稳定工作，再考虑旁路由、透明代理或主网关。网络节点最怕一上来就改全网拓扑，出问题时很难判断是哪一层坏了。

## 为什么单独建代理网关

在 `infra-docker-01` 上测试 Docker：

```bash
sudo docker run hello-world
```

拉取镜像失败。继续测试 Docker Registry：

```bash
curl -4I --connect-timeout 10 https://registry-1.docker.io/v2/
curl -6I --connect-timeout 10 https://registry-1.docker.io/v2/
```

IPv4 和 IPv6 都超时，基本可以判断 Docker Hub 直连不可用。

原本 PVE 本体上已经有 `v2raya.service`，理论上可以直接借用。但这次维护的核心目标就是让 PVE 本体变干净，所以代理服务不应该继续留在宿主机上。

因此我新建了一个网络节点：

```text
名称：net-gateway-01
系统：OpenWrt x86_64
当前角色：旁路代理网关
未来可能：旁路由 / 主网关 / 软路由
```

## 为什么选 OpenWrt

一开始也考虑过 Debian 13。Debian 更适合普通 Linux 服务、systemd 脚本和原生二进制部署，维护起来也更熟悉。

但这个节点未来可能承担更多网络职责：

```text
代理网关
DNS 分流
Tailscale 子网路由
旁路由
透明代理
主网关 / 软路由
```

从定位上看，这个节点更像网络设备，而不是普通服务器。OpenWrt 在 LuCI、DNS、防火墙、代理插件和软路由生态上更接近目标用途，所以最后选择 OpenWrt。

## 选择镜像

镜像使用 OpenWrt 官方 Firmware Selector 构建。

选择项：

```text
设备：Generic x86/64
版本：OpenWrt 25.12.4
镜像类型：COMBINED-EFI (SQUASHFS)
```

这里没有选 `ROOTFS`，因为它只是 root 文件系统，不是完整启动盘。

普通 `COMBINED` 也没有选，因为 PVE VM 使用 OVMF / UEFI 启动，更适合 `COMBINED-EFI`。

文件系统选择 `SQUASHFS`，没有选 `EXT4`。原因是它更符合 OpenWrt 固件式系统的思路：系统主体相对只读，配置和改动在 overlay 层，后续恢复和升级更接近路由器逻辑。

在 Firmware Selector 中额外加入基础包：

```text
curl
wget-ssl
nano
bash
htop
ip-full
kmod-tun
ca-certificates
luci-ssl
luci-app-ttyd
```

用途：

```text
curl / wget：下载插件和测试网络
nano / bash：方便维护
htop：查看系统状态
ip-full：网络排错
kmod-tun：为后续 Tailscale / VPN / TUN 预留能力
luci-ssl：HTTPS LuCI
luci-app-ttyd：Web 终端
```

## 首次启动配置

OpenWrt 默认 LAN IP 是 `192.168.1.1`，并且会启用 DHCP。直接接入现有局域网有冲突风险，这一步不能省。

所以在 Firmware Selector 的首次启动脚本中提前写入配置：

```sh
uci set network.lan.ipaddr='192.168.3.20'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.gateway='192.168.3.1'
uci set network.lan.dns='192.168.3.1 223.5.5.5 1.1.1.1'

uci set dhcp.lan.ignore='1'

uci commit network
uci commit dhcp

/etc/init.d/dnsmasq disable
/etc/init.d/odhcpd disable
```

目标状态：

```text
OpenWrt LAN IP：192.168.3.20
网关：192.168.3.1
DNS：192.168.3.1 / 223.5.5.5 / 1.1.1.1
DHCP：关闭
```

这样第一次启动后，它不会抢主路由的 DHCP，也不会变成意外的默认网关。

## 在 PVE 中创建 VM

OpenWrt 下载得到的是 `.img.gz`，解压后是完整磁盘镜像，不是 Debian 那种安装 ISO。

所以流程不是：

```text
创建 VM → 挂载 ISO → 安装系统
```

而是：

```text
创建 VM 硬件壳子 → 导入 OpenWrt img 作为系统盘 → 设置启动顺序 → 直接开机
```

VM 配置：

```text
名称：net-gateway-01
VMID：120
系统：OpenWrt x86_64
CPU：2 核
内存：1G 或 2G
磁盘：导入 OpenWrt 镜像
网卡：VirtIO，桥接 vmbr0
BIOS：OVMF (UEFI)
机型：q35
EFI 磁盘：启用
TPM：不启用
PVE 防火墙：迁移阶段先关闭
```

实际镜像文件名：

```text
openwrt-25.12.4-965ee766a1ca-x86-64-generic-squashfs-combined-efi.img
```

导入命令：

```bash
qm importdisk 120 openwrt-25.12.4-965ee766a1ca-x86-64-generic-squashfs-combined-efi.img local-lvm
```

这里踩过一个小坑：命令里的文件名少了中间的构建 ID `965ee766a1ca`，PVE 提示文件不存在。改成实际文件名后导入成功。

导入后，在 PVE Web 页面中把 `Unused Disk 0` 添加为 SCSI 磁盘，并把它设置为第一启动项。

## 解决 Secure Boot 启动失败

首次启动时遇到：

```text
failed to load Boot0002 ... Access Denied
Start PXE over IPv4
```

这说明 UEFI 找到了 OpenWrt 磁盘，但启动文件被 Secure Boot 拦截。

原因是创建 VM 时 EFI 磁盘启用了“预注册密钥”。

处理方式：

1. 关闭 VM。
2. 删除原来的 EFI Disk。
3. 重新添加 EFI Disk。
4. 不勾选“预注册密钥”。
5. 确认 OpenWrt 系统盘在启动顺序第一位。
6. 重新启动 VM。

重新启动后，OpenWrt 正常进入系统。

## 初始状态检查

启动成功后，控制台会出现：

```text
Please press Enter to activate this console.
```

按 Enter 进入控制台后，先设置 root 密码：

```sh
passwd
```

然后检查网络状态：

```sh
ip addr show br-lan
ip route
uci show network.lan
uci show dhcp.lan
```

预期结果：

```text
br-lan：192.168.3.20/24
default via 192.168.3.1
dhcp.lan.ignore='1'
```

再测试内网、公网和 DNS：

```sh
ping -c 3 192.168.3.1
ping -c 3 223.5.5.5
ping -c 3 openwrt.org
```

确认无误后，就可以访问 LuCI：

```text
http://192.168.3.20
```

## 安装中文语言包

初始 LuCI 和 OpenClash 页面是英文。为了后续维护方便，先安装中文语言包：

```sh
apk update
apk add luci-i18n-base-zh-cn luci-i18n-firewall-zh-cn luci-i18n-package-manager-zh-cn
```

设置 LuCI 语言：

```sh
uci set luci.main.lang='zh_cn'
uci commit luci
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
/etc/init.d/uhttpd restart
```

刷新浏览器后，LuCI 主界面切换为中文。

这一阶段没有安装第三方主题，例如 Argon。原因很简单：当前优先级是网络和代理稳定，不希望主题、缓存和插件问题混进排错过程。

## 安装 OpenClash

OpenWrt 25.12 使用 `apk` 作为包管理器，因此安装依赖时使用：

```sh
apk update
apk add bash curl ca-bundle ca-certificates ip-full unzip kmod-tun kmod-inet-diag kmod-nft-tproxy luci-compat luci luci-base
```

先确认能访问 GitHub：

```sh
curl -I --connect-timeout 10 https://github.com
```

返回 `HTTP/2 200` 后，再安装 OpenClash 的 LuCI 插件。

安装完成后进入 OpenClash 页面时，会提示：

```text
You have not installed the core yet, do you want to download and install it now?
```

这里的 core 指 OpenClash 后端实际运行的代理核心，例如 Mihomo / Clash。选择确认后安装 Mihomo 核心。

安装完成后，页面显示：

```text
OpenClash
A Mihomo(Clash) Client For OpenWrt
```

## OpenClash 基础配置

当前目标不是透明代理，而是给 `infra-docker-01` 提供一个局域网代理端口。

因此没有启用：

```text
TUN 模式
透明代理
Fake-IP
DNS 劫持
旁路由模式
默认网关接管
```

所以这里只保留显式代理。

OpenClash 端口如下：

```text
DNS 监听端口：7874
流量转发端口：7892
TProxy 端口：7895
HTTP(S) 代理端口：7890
SOCKS5 代理端口：7891
HTTP(S)&SOCKS 混合代理端口：7893
```

Docker daemon 需要 HTTP / HTTPS 代理，所以最终使用：

```text
http://192.168.3.20:7890
```

## 导入订阅与排错

OpenClash 中添加订阅配置时，使用“订阅链接”方式，而不是上传文件。

配置要点：

```text
订阅地址：粘贴 Clash 订阅链接
User-Agent：保持默认 clash-verge/v2.4.5
在线订阅转换：不启用
筛选节点：留空
排除节点：留空
配置名称：使用简单名称，例如 main
```

没有启用在线订阅转换，因为这可能会把订阅链接发送到第三方转换服务，不利于安全。

导入后遇到过两个问题。

第一个是旧订阅商本身异常，导致节点可用性不稳定。更换订阅并手动选择可用节点后，代理恢复正常。

第二个是代理认证问题：

```text
HTTP/1.1 407 Proxy Authentication Required
Proxy-Authenticate: Basic
```

后来发现认证来自 OpenClash 的“覆写配置”，关闭后问题解决。

这里要分清楚几类问题：

```text
OpenClash 本体问题
订阅内容问题
节点可用性问题
覆写配置问题
客户端代理配置问题
```

不要看到代理失败就直接重装系统，否则排错范围会被自己扩大。

## IP 冲突事故

中间还遇到一次 IP 冲突。

服务器异常后远程重启，发现无法访问：

```text
192.168.3.20
```

排查后发现，是另一台开机自启的虚拟机获取了和 OpenWrt 重合的 IP，导致 `net-gateway-01` 无法正常占用 `192.168.3.20`。

处理方式：

```text
关停冲突 VM
恢复 net-gateway-01 的 192.168.3.20
```

这次事故说明关键基础设施节点不能只靠“手动记忆 IP”，必须规划静态地址区和 DHCP 地址池。

建议规划：

```text
192.168.3.1       主路由
192.168.3.16      PVE 本体
192.168.3.20      net-gateway-01
192.168.3.30      infra-docker-01
192.168.3.100-199 DHCP 自动分配池
```

固定设备尽量放在 DHCP 池之外，避免重启后再次冲突。

## 配置 Docker daemon 代理

在 `infra-docker-01` 上先测试代理连通性：

```bash
curl -x http://192.168.3.20:7890 -I --connect-timeout 15 https://www.google.com
curl -x http://192.168.3.20:7890 -I --connect-timeout 15 https://registry-1.docker.io/v2/
```

其中 Docker Registry 返回 `401 Unauthorized` 是正常现象，说明网络已经打通，只是未认证访问 Docker Registry。

随后为 Docker daemon 配置 systemd 代理：

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo nano /etc/systemd/system/docker.service.d/http-proxy.conf
```

写入：

```ini
[Service]
Environment="HTTP_PROXY=http://192.168.3.20:7890"
Environment="HTTPS_PROXY=http://192.168.3.20:7890"
Environment="NO_PROXY=localhost,127.0.0.1,::1,192.168.3.0/24,100.64.0.0/10,.home.arpa"
```

应用配置：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl show --property=Environment docker
```

最后测试：

```bash
sudo docker run --rm hello-world
```

测试成功后，说明 Docker 拉取镜像已经可以通过 `net-gateway-01` 完成。

## 当前状态

当前 `net-gateway-01` 已完成：

```text
OpenWrt x86_64 启动成功
LuCI 可访问
中文界面正常
DHCP 已关闭
静态 IP：192.168.3.20
OpenClash 已安装
Mihomo 核心已安装
订阅已导入
可用节点已手动选择
HTTP(S) 代理端口 7890 可用
infra-docker-01 Docker daemon 已成功通过 192.168.3.20:7890 拉取镜像
```

仍未启用：

```text
透明代理
TUN 模式
Fake-IP
DNS 劫持
旁路由模式
主网关模式
DHCP 服务
```

这是有意为之。当前阶段优先保证稳定，只作为旁路代理网关使用。

## 后续演进

后续可以分阶段增强：

第一阶段：

```text
仅作为代理服务器使用
infra-docker-01 显式配置 Docker HTTP_PROXY / HTTPS_PROXY
```

第二阶段：

```text
为部分 VM 提供旁路由能力
让部分测试 VM 的默认网关指向 192.168.3.20
增加 DNS 分流
```

第三阶段：

```text
接入 Tailscale 子网路由
尝试透明代理
增加更细粒度的防火墙规则
```

第四阶段，未来可选：

```text
升级为真正主网关 / 软路由
接管 DHCP、DNS、NAT、防火墙、端口转发
```

当前不建议立刻进入主网关模式。PVE 服务迁移还没完成，过早改变全网拓扑会显著增加风险。

## 经验总结

这次部署之后，我会把几个经验记下来：

1. OpenWrt 更适合当网络设备，不一定适合当普通服务器。
2. 初次接入现有局域网时，一定要关闭 DHCP。
3. PVE 中运行 OpenWrt x86_64，如果使用 UEFI 镜像，要注意 Secure Boot / 预注册密钥问题。
4. OpenWrt 作为旁路代理网关时，一张网卡就够，不需要一开始就做复杂双网卡软路由。
5. Docker 需要的是 HTTP(S) 代理，用 OpenClash 的 7890 端口即可。
6. 不要一开始就开启透明代理、TUN、Fake-IP 和 DNS 劫持，先让显式代理稳定工作。
7. 固定 IP 必须和 DHCP 池隔离，否则重启后很容易发生 IP 冲突。
8. OpenClash 排错时要分清订阅、节点、覆写配置和客户端配置。
9. 网络基础设施应该单独成节点，避免继续堆在 PVE 宿主机上。

到这里，PVE 服务分层迁移的底座基本成型：`infra-docker-01` 承接 Docker 服务，`net-gateway-01` 提供代理能力，PVE 本体开始逐步回归虚拟化宿主机的角色。
