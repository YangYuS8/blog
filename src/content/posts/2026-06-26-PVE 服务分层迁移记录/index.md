---
title: "PVE 服务分层迁移记录"
urlSlug: 'pve-service-layering-migration'
published: 2026-06-26
description: '记录一次家用 PVE 服务器维护：从宿主机直接承载 Docker、媒体、代理和面板服务，逐步整理为虚拟化宿主机、Docker 服务机和代理网关分层的过程。'
image: ''
author: ""
tags: ["PVE", "Docker", "Homelab", "虚拟化", "实战记录", "服务迁移"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这次维护不是某个服务突然坏了，而是我发现 PVE 宿主机已经被自己越用越“重”。

最开始为了方便，我把很多东西都直接跑在 PVE 本体上：Docker、1Panel、OpenList、v2rayA、Tailscale、OpenResty、Jenkins、Jellyfin、qBittorrent、Radarr、Prowlarr、AutoBangumi、Komga、Komf、Navidrome、RustFS、Sun-Panel 等。

刚开始这样确实省事。宿主机装好服务就能用，不用额外建 VM，也不用先设计网络和数据目录。但服务越堆越多之后，PVE 本体逐渐变成了一个混合体：它既是虚拟化宿主机，又是 Docker 宿主机、下载器、媒体服务机、反代入口、代理节点和远程管理入口。

这篇文章记录这次整理的第一阶段：先把服务边界重新划出来，新建 `infra-docker-01` 作为后续 Docker 服务迁移的承载节点，再配合 `net-gateway-01` 解决 Docker Hub 访问问题。

## 当前问题

整理前，PVE 宿主机上除了 PVE 自身服务外，还直接运行了不少业务相关服务：

```text
1panel-agent.service
1panel-core.service
docker.service
containerd.service
openlist.service
v2raya.service
tailscaled.service
zabbix-agent2.service
```

Docker 里也有大量容器：

```text
jenkins
peerbanhelper
radarr
qbittorrent
navidrome
flaresolverr
prowlarr
sun-panel
jellyfin
AutoBangumi
suwayomi
komga
komf
rustfs
openresty
```

对应的 Compose 配置还分散在两个地方：

```text
/opt/1panel/apps/...
/mnt/pve/sda/docker/...
```

到这里已经能看出问题：服务来源不统一，一部分由 1Panel 管理，一部分是手写 Docker Compose，一部分则是宿主机 systemd 服务。

## 为什么要迁移

直接触发这次整理的问题，是 PVE 本体上的 Tailscale 延迟明显高于它上面的虚拟机，远程 SSH 体验很差。

Tailscale 本身可以继续单独排查，但从整体架构看，真正的问题是 PVE 本体承担了太多职责：

```text
PVE 宿主机
Docker 宿主机
1Panel 面板机
OpenResty 反向代理入口
下载器 / 媒体服务机
Jenkins 构建机
OpenList 文件服务机
v2rayA 代理机
Tailscale 远程入口
Zabbix Agent 监控节点
```

这些角色混在一起，平时不一定立刻出问题，但一旦需要排查，就会很难受：

1. 网络环境变复杂：Docker bridge、PVE bridge、tailscale0、v2rayA、OpenResty、qBittorrent 等混在一起。
2. 排错边界不清晰：问题可能来自 PVE、防火墙、Docker、代理、Tailscale 或某个容器。
3. 安全边界变差：PVE 本体暴露了太多非必要服务端口。
4. 备份迁移困难：业务数据分散在 `/opt/1panel`、`/var/lib/docker`、`/mnt/pve/sda/docker` 等路径。
5. 宿主机不再稳定干净：PVE 本该专注虚拟化，现在却变成了业务运行环境。

所以这次维护的目标不是“把某个服务修好”，而是让 PVE 逐步回到虚拟化宿主机的角色。

## 新的分层规划

我希望整理后的结构更清楚一些：

```text
PVE 本体
  只保留虚拟化、存储、网络桥、SSH、Tailscale 管理入口、监控 Agent

infra-docker-01
  承接 Docker / Compose / 1Panel / 业务服务

net-gateway-01
  承接代理网关，未来可扩展为旁路由或主网关

其他 VM / CT
  按用途承接监控、Kubernetes 实验、Agent 实验等
```

当前阶段先不急着搬所有业务，而是先把底座搭好：

1. 新建 Docker 服务机 `infra-docker-01`。
2. 新建网络代理网关 `net-gateway-01`。
3. 让 `infra-docker-01` 能通过代理正常访问 Docker Hub。
4. 后续再逐个迁移 PVE 本体上的 Compose 服务。

## 创建 Docker 服务机

`infra-docker-01` 是后续承接 Docker 服务的 VM，最终配置如下：

```text
主机名：infra-docker-01
系统：Debian 13
IP：192.168.3.30
CPU：4 核
内存：12G
系统盘：64G
数据盘：200G
网卡：VirtIO，桥接 vmbr0
用途：承接 Docker / Compose / 1Panel / 业务服务
```

PVE 中创建 VM 时使用的关键配置：

```text
机型：q35
BIOS：OVMF (UEFI)
EFI 磁盘：启用
Qemu Agent：启用
TPM：不启用
SCSI 控制器：VirtIO SCSI single
磁盘总线：SCSI
IO thread：启用
系统盘丢弃：启用
CPU 类型：host
NUMA：不启用
网络模型：VirtIO
PVE 防火墙：迁移阶段先关闭
```

Debian 安装时保持最小化，只装后续维护真正需要的东西：

```text
不安装桌面环境
勾选 SSH server
勾选标准系统工具
普通用户：yangyus8
主机名：infra-docker-01
域名：home.arpa
```

系统装完后，先把基础环境处理好：

- 配置 sudo 权限；
- 安装 `qemu-guest-agent`；
- 将系统语言改成英文，避免 PVE 控制台中文乱码；
- 配置静态 IP；
- 修复 DNS 解析。

## 配置静态网络

Debian 安装完成后，网卡名为 `ens18`。初始 DHCP 获取到 `192.168.3.13`，后续改成静态 IP：

```text
IP：192.168.3.30/24
网关：192.168.3.1
DNS：192.168.3.1 / 223.5.5.5 / 1.1.1.1
```

这里遇到过一个小问题：DNS 没有生效。

```text
ping 223.5.5.5 正常
ping debian.org 失败
ping baidu.com 失败
```

也就是 IP 路由正常，但域名解析失败。检查 `/etc/resolv.conf` 后发现里面没有有效的 `nameserver`。

最后通过安装并配置 `resolvconf`，让 `/etc/network/interfaces` 中的 `dns-nameservers` 能正确写入解析配置。

最终状态：

```text
ens18：192.168.3.30/24
default via 192.168.3.1
DNS 正常
公网 IP 可访问
域名解析正常
```

## 处理数据盘

这台 VM 有两块盘，我一开始就把系统盘和数据盘分开：

```text
64G 系统盘
200G 下载 / 媒体数据盘
```

一开始磁盘名出现过变化。最初看起来系统盘是 `/dev/sda`，数据盘是 `/dev/sdb`，重启后变成：

```text
/dev/sda = 200G 数据盘
/dev/sdb = 64G 系统盘
```

这也提醒我：Linux 下 `/dev/sda`、`/dev/sdb` 不能当作稳定标识。判断磁盘时应该看：

```text
SIZE
FSTYPE
MOUNTPOINTS
UUID
```

最终确认：

```text
sda     200G    空盘
sdb      64G    系统盘
├─sdb1  EFI     /boot/efi
├─sdb2  ext4    /
└─sdb3  swap    [SWAP]
```

随后对 200G 数据盘分区和格式化：

```bash
sudo parted /dev/sda --script mklabel gpt
sudo parted /dev/sda --script mkpart primary ext4 0% 100%
sudo mkfs.ext4 -L data /dev/sda1
```

得到的数据盘 UUID：

```text
/dev/sda1
LABEL="data"
UUID="31d7d9de-c075-4d1c-a4b0-ef3c8b032024"
TYPE="ext4"
```

挂载到 `/data`，并写入 `/etc/fstab`：

```text
UUID=31d7d9de-c075-4d1c-a4b0-ef3c8b032024 /data ext4 defaults,noatime 0 2
```

最终目录结构：

```text
/data
├── downloads
├── media
├── torrents
└── temp
```

然后把 `/data` 所有权交给普通用户：

```bash
sudo chown -R yangyus8:yangyus8 /data
```

最终磁盘状态：

```text
/dev/sdb2  -> /
/dev/sdb1  -> /boot/efi
/dev/sda1  -> /data
```

## 安装 Docker

在 `infra-docker-01` 上安装 Docker 官方源后，Docker 安装成功：

```text
Docker Engine：29.6.0
Docker Compose：v5.2.0
Docker Root Dir：/var/lib/docker
```

目录规划先保持简单，不一开始就把结构搞得过度复杂：

```text
Docker 程序和镜像层：/var/lib/docker，放系统盘
Compose 配置文件：/srv/docker
下载 / 媒体大文件：/data
```

这里没有把 Docker 根目录直接放到 `/data`。Docker 镜像层、容器层、小文件和数据库随机 IO 较多，放机械盘上不太合适。

后续下载、媒体这类大文件数据放 `/data`，Docker 自身仍留在系统盘。

## Docker Hub 访问问题

Docker 安装完成后，测试：

```bash
sudo docker run hello-world
```

结果拉取失败。继续测试 Docker Registry：

```bash
curl -4I --connect-timeout 10 https://registry-1.docker.io/v2/
curl -6I --connect-timeout 10 https://registry-1.docker.io/v2/
```

IPv4 和 IPv6 都超时，说明问题不是 Docker 安装本身，而是 Docker Hub 网络访问环境不稳定。

到这里有两个选择：

1. 临时借用 PVE 本体上的 `v2raya.service`；
2. 新建独立代理网关，让 Docker 服务机通过它访问外部网络。

因为这次整理的目标就是让 PVE 本体变干净，所以没有继续把代理留在 PVE 宿主机上，而是新建 `net-gateway-01` 作为代理网关。

`net-gateway-01` 的部署过程单独写在另一篇文章里：[OpenWrt 旁路代理网关部署](/posts/openwrt-sidecar-proxy-gateway/)。代理网关打通后，`infra-docker-01` 最终可以正常拉取 `hello-world`。

## 当前节点状态

这一阶段完成后，关键节点关系基本清楚了：

```text
PVE 本体：192.168.3.16
net-gateway-01：192.168.3.20
infra-docker-01：192.168.3.30
主路由：192.168.3.1
```

当前完成事项：

```text
1. 梳理了 PVE 本体服务混乱问题
2. 确定了后续分层迁移方向
3. 新建并初始化 infra-docker-01
4. 完成静态 IP、DNS、sudo、qemu-agent、数据盘挂载
5. 安装 Docker
6. 确认 Docker Hub 访问需要代理
7. 通过 net-gateway-01 提供代理后，Docker 拉取 hello-world 成功
```

## 后续迁移顺序

后续服务迁移不适合一口气全搬。我的计划是按“先轻后重”的顺序处理，先迁移依赖少、回滚容易的服务。

第一批轻服务：

```text
sun-panel
flaresolverr
prowlarr
radarr
suwayomi
komf
peerbanhelper
AutoBangumi
```

第二批较重服务：

```text
jellyfin
navidrome
komga
qbittorrent
rustfs
jenkins
openresty
1panel
```

最后再处理：

```text
openlist
v2raya
tailscale 入口
PVE 本体 Docker 清理
```

最终目标：

```text
PVE 本体不再运行 Docker / 1Panel / OpenList / v2rayA 等业务服务
Docker 业务统一迁到 infra-docker-01
代理和网络入口统一迁到 net-gateway-01
PVE 只保留虚拟化宿主机职责
```

## 经验总结

这次维护最大的收获不是某条命令，而是边界感。

家用 PVE 很容易因为“临时方便”变成万能服务器。短期看能跑就行，长期看，网络、权限、数据、备份和排错都会慢慢变复杂。

这次整理后，我会把几个原则固定下来：

1. PVE 本体不要长期充当业务服务器。
2. Docker、代理、媒体服务、下载器尽量放到独立 VM。
3. 关键服务 IP 要固定，并从 DHCP 池中排除。
4. Linux 磁盘挂载必须使用 UUID，不要依赖 `/dev/sda`、`/dev/sdb`。
5. 服务迁移先建底座，再迁轻服务，最后迁核心服务。
6. 家用服务器也需要清晰的网络规划、命名规划和服务边界。

下一篇会继续记录 `net-gateway-01`：在 PVE 中部署 OpenWrt 作为旁路代理网关，并让 `infra-docker-01` 通过它成功拉取 Docker 镜像。
