---
title: "媒体基础设施路径规划"
urlSlug: 'homelab-media-storage-download-layout'
published: 2026-06-28
description: '记录 PVE 服务整理后的第五阶段：在 infra-docker-01 上重新挂载 NAS 媒体目录，规划 /data/media 与 /data/downloads 路径，并把 qBittorrent 定位为统一下载底座。'
image: ''
author: ""
tags: ["Docker", "NAS", "SMB", "Jellyfin", "qBittorrent", "Homelab", "实战记录"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这是 PVE 服务整理的第五篇记录。

前一篇处理的是容器更新策略：不继续引入 Watchtower，而是用中立标签保留未来可控更新能力。

- [容器更新策略与 Watchtower 取舍](/posts/homelab-container-update-policy-watchtower/)

这一篇开始进入媒体服务迁移。但媒体服务不能一上来就搬 Jellyfin、qBittorrent、Radarr 这些容器。它们背后依赖大量目录：番剧、电影、音乐、漫画、下载中目录、导入目录、配置目录。

所以这一步的重点不是“部署更多服务”，而是先把媒体基础设施重新规划清楚。

## 当前目标

新主机仍然是：

```text
Hostname: infra-docker-01
IP: 192.168.3.30
```

这一阶段要解决几个问题：

```text
NAS 媒体目录如何挂载
容器统一看到哪些路径
下载中的文件放在哪里
哪些服务读写媒体库
Jellyfin、Navidrome、Komga 的职责如何拆分
qBittorrent 是单一服务附属品，还是统一下载底座
```

最后形成的结构是：

```text
/data/media/anime  -> 番剧媒体库
/data/media/movie  -> 电影媒体库
/data/media/music  -> 音乐媒体库
/data/media/manga  -> 漫画媒体库
/data/downloads    -> 统一下载工作区
```

## NAS 媒体目录

原来 PVE 上的媒体目录来自 NAS，通过 CIFS/SMB 挂载：

```text
//192.168.3.3/anime
//192.168.3.3/movie
//192.168.3.3/music
```

在 PVE 上分别挂载到：

```text
/mnt/pve/sda/data/anime
/mnt/pve/sda/data/movie
/mnt/pve/sda/data/music
```

这次迁移没有复制媒体文件，而是在 `infra-docker-01` 上重新挂载 NAS。

原因很简单：媒体文件体积大，复制一份既浪费时间，也会制造新的同步问题。媒体数据仍然集中放在 NAS 上，新主机只负责通过标准路径访问它们。

新的路径设计为：

```text
/data/media/anime
/data/media/movie
/data/media/music
/data/media/manga
```

其中前三个目录通过 CIFS/SMB 挂载到 NAS：

| 本机路径 | 用途 |
| --- | --- |
| `/data/media/anime` | 番剧 |
| `/data/media/movie` | 电影 |
| `/data/media/music` | 音乐 |
| `/data/media/manga` | 漫画，先作为本地标准路径预留 |

`manga` 暂时不从 NAS 挂载，后续给 Suwayomi、Komga 和 Komf 使用。

## 挂载参数

挂载参数基本沿用 PVE 上验证过的方式：

```text
credentials=/etc/nas-credentials
uid=1000
gid=1000
iocharset=utf8
vers=3.0
nofail
```

这次在新主机上额外加入了：

```text
x-systemd.automount
_netdev
```

这两个参数的目的，是减少开机时 NAS 暂时不可用导致系统卡住的风险。

也就是说，媒体目录不要求在系统启动阶段立刻完全可用，而是通过 systemd automount 在访问时再触发挂载。

这对 homelab 很实用：NAS、交换机、虚拟机、网关的启动顺序不一定每次都完全一致，挂载应该尽量容忍这种情况。

## 服务职责拆分

原来的 PVE 环境里，很多服务对媒体目录的访问比较随意。迁移到新主机后，我希望每个服务只负责自己的边界。

新的职责划分是：

| 服务 | 职责 |
| --- | --- |
| Navidrome | 管理音乐 |
| Jellyfin | 管理视频 |
| Komga | 管理漫画库 |
| qBittorrent | 通用下载底座 |
| ANI-RSS | 番剧订阅和下载任务来源 |
| Radarr | 电影自动化管理 |
| Prowlarr | 索引器管理 |
| Suwayomi | 漫画源和下载 |
| Komf | Komga 元数据补全 |

这里有一个重要调整：Jellyfin 不再默认管理音乐。

音乐交给 Navidrome，Jellyfin 只做视频媒体库。这样职责更清晰，也减少 Jellyfin 对媒体目录的访问范围。

最终关系变成：

```text
Navidrome:
  /data/media/music

Jellyfin:
  /data/media/anime
  /data/media/movie

Komga:
  /data/media/manga

qBittorrent:
  /data/downloads
  /data/media/anime
  /data/media/movie
  /data/media/manga
```

## 先用 Navidrome 验证挂载

媒体目录挂载完成后，我先部署 Navidrome。

选择 Navidrome 的原因是它足够适合作为媒体挂载验证服务：

```text
只需要读取 /data/media/music
不涉及下载器
不涉及硬链接
不会修改媒体目录
配置相对简单
```

Navidrome 的标准路径为：

```text
配置目录: /data/docker/config/navidrome
音乐目录: /data/media/music:ro
端口: 4533
```

启动后，Navidrome 成功创建数据库并开始扫描音乐目录。

这一点验证了几件事：

```text
CIFS 挂载路径可用
容器可以读取媒体路径
配置目录可以正常写入
Git -> deploy-stack.sh -> 运行目录 这条链路继续有效
```

也就是说，媒体服务迁移不再只是理论上的目录规划，而是已经通过一个真实服务跑通了基础链路。

## qBittorrent 的定位

在迁移追番和电影自动化之前，我重新设计了 qBittorrent 的定位。

它不应该只是 ANI-RSS 的附属下载器，也不应该只是 Radarr 的附属下载器。

更合理的定位是：

```text
qBittorrent = 通用下载基础设施
ANI-RSS     = 番剧任务来源
Radarr      = 电影任务来源
手动下载    = 人工任务来源
未来其他服务 = 其他任务来源
```

所以这次不是给某个服务随便挂一个下载目录，而是先建立统一下载工作区。

目录结构如下：

```text
/data/downloads
├── incomplete
├── manual
├── ani-rss
├── radarr
└── temp
```

qBittorrent 中对应规划分类：

| 分类 | 完成目录 |
| --- | --- |
| `ani-rss` | `/data/media/anime` |
| `radarr` | `/data/downloads/radarr` |
| `manual` | `/data/downloads/manual` |
| `temp` | `/data/downloads/temp` |

每个分类再单独设置不完整下载目录：

```text
/data/downloads/incomplete/ani-rss
/data/downloads/incomplete/radarr
/data/downloads/incomplete/manual
/data/downloads/incomplete/temp
```

这样可以避免 Jellyfin 或其他媒体库服务扫描到半成品文件。

## 番剧下载路径

对于番剧，我决定让 ANI-RSS 通过 qBittorrent 直接落到：

```text
/data/media/anime
```

原因是 ANI-RSS 本身就是追番订阅和整理工具，它的目标就是把番剧按可识别结构送进媒体库。

只要 qBittorrent 的 `ani-rss` 分类设置了独立的不完整下载路径，下载中的半成品就不会污染媒体库。

最终链路是：

```text
ANI-RSS
  -> qBittorrent category: ani-rss
  -> 下载中: /data/downloads/incomplete/ani-rss
  -> 完成后: /data/media/anime
  -> Jellyfin Anime 库扫描
```

这里的关键是“下载中”和“完成后”必须分开。

## 电影下载路径

电影和番剧不同。

电影更适合让 Radarr 负责导入、重命名和管理。所以 qBittorrent 的 `radarr` 分类不直接写入电影媒体库，而是保存到：

```text
/data/downloads/radarr
```

然后由 Radarr 导入到：

```text
/data/media/movie
```

这样职责更清楚：

```text
下载器只负责下载
Radarr 负责电影库管理
Jellyfin 只扫描最终媒体库
```

这里还有一个现实限制：`/data/media/movie` 是 CIFS/SMB 挂载，而 `/data/downloads/radarr` 在本机磁盘上，两者不在同一个本地文件系统。

所以后续可能不能依赖 hardlink。当前先接受 copy/move 导入模式，等链路稳定后再考虑是否需要优化。

## Jellyfin 只做视频库

Jellyfin 部署时，我一开始考虑把音乐也挂进去，后来放弃了。

现在的职责划分是：

```text
Navidrome -> 音乐
Jellyfin  -> 视频
Komga     -> 漫画
```

所以 Jellyfin 的媒体挂载只保留：

```text
/data/media/anime:ro
/data/media/movie:ro
```

不再挂载：

```text
/data/media/music
```

初始媒体库规划为：

| Jellyfin 库 | 路径 | 类型 |
| --- | --- | --- |
| Anime | `/data/media/anime` | 节目 |
| Movies | `/data/media/movie` | 电影 |

高级设置先保持克制：

```text
不让 Jellyfin 写入媒体目录
不一开始就开启复杂缩略图生成
不急着安装插件
不急着配置硬件转码
先确认路径和基础扫描正常
```

这样后续出问题时，排查范围更小。

## 当前结构

这一阶段完成后，媒体基础设施已经形成清晰结构：

```text
/data/media/anime  -> ANI-RSS / Jellyfin
/data/media/movie  -> Radarr / Jellyfin
/data/media/music  -> Navidrome
/data/media/manga  -> Suwayomi / Komga / Komf

/data/downloads    -> qBittorrent 下载工作区
```

服务职责也更清楚：

```text
qBittorrent 不属于任何单一上层服务
ANI-RSS 只负责追番自动化
Radarr 只负责电影自动化
Jellyfin 只负责视频媒体库
Navidrome 只负责音乐
Komga 只负责漫画库
```

这一步的价值在于，不是把 PVE 上的旧服务原样搬过来，而是先重建路径、权限和职责边界。

后面真正迁移 Jellyfin、qBittorrent、ANI-RSS、Radarr 时，它们会落在同一套目录语义里，而不是各自带着旧环境的混乱路径继续运行。
