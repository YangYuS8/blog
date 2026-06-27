---
title: "媒体自动化服务迁移"
urlSlug: 'homelab-media-automation-migration'
published: 2026-06-28
description: '记录 PVE 服务整理后的第六阶段：在 infra-docker-01 上迁移 Komga、Suwayomi、Komf、qBittorrent、ANI-RSS、Jellyfin、Radarr，并接入 Prowlarr，重建媒体自动化链路。'
image: ''
author: ""
tags: ["Docker", "Jellyfin", "qBittorrent", "Radarr", "Prowlarr", "Homelab", "实战记录"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这是 PVE 服务整理的第六篇记录。

前一篇先处理了媒体基础设施：NAS 挂载、`/data/media` 路径规划，以及 `/data/downloads` 下载工作区。

- [媒体基础设施路径规划](/posts/homelab-media-storage-download-layout/)

这一篇开始真正迁移媒体自动化服务。

目标不是完整复制旧 PVE 配置，而是遵循前面已经确定的原则：

```text
先让标准化 stack 干净运行
不直接迁移旧配置
每个服务先跑通基础功能
再逐步配置业务联动
```

这次涉及的服务比较多：

```text
Navidrome
Komga
Suwayomi
Komf
qBittorrent
ANI-RSS
Jellyfin
Radarr
Prowlarr
```

其中 Prowlarr 前面已经部署过，这一阶段主要是把它接入 Radarr。

## 漫画链路

漫画相关服务先从 Komga 开始。

Komga 的定位是漫画库服务，负责扫描和展示漫画目录。新的标准路径为：

```text
配置目录: /data/docker/config/komga
漫画目录: /data/media/manga
端口: 25600
```

这次没有迁移旧配置，而是让 Komga 从空配置开始初始化。

首次启动时，Komga 进行了大量数据库迁移。这是正常现象，因为它需要创建自己的 SQLite 数据库和任务数据库。

最终日志显示服务启动成功，Tomcat 监听在 `25600` 端口，浏览器访问也能返回正常页面。

这说明：

```text
Komga 容器正常运行
配置目录可以写入
/data/media/manga 可以作为漫画库路径
服务已经加入 homelab Docker 网络
```

由于漫画目录还没有正式整理，日志里出现 `entities: 0` 这类信息也是正常的。这里先跑通服务，不急着整理媒体内容。

## Suwayomi

接下来部署 Suwayomi。

Suwayomi 的定位是漫画源和下载服务，后续可以和 Komga 共享漫画目录：

```text
Suwayomi 下载漫画
↓
写入 /data/media/manga
↓
Komga 扫描 /data/media/manga
```

新的路径设计为：

```text
配置目录: /data/docker/config/suwayomi
下载目录: /data/media/manga
端口: 4567
```

启动时，Suwayomi 执行了数据库迁移，并在第一次启动时下载 WebUI。

日志中出现了一些 DBus、Java、JCEF 相关警告，但服务最终成功监听在：

```text
http://0.0.0.0:4567/
```

用 `curl` 测试返回：

```text
HTTP/1.1 200 OK
```

这说明服务已经正常对外提供页面。

这里有一个后续观察点：Suwayomi 第一次启动时会在线下载 WebUI。如果以后每次重启都重新下载，就需要再考虑 WebUI 缓存或固定版本问题。但目前第一次启动已经成功，不需要马上处理。

## Komf 排查

Komf 是这一阶段最值得记录的故障排查案例。

Komf 的定位是 Komga 的元数据辅助服务，可以给 Komga 补充漫画元数据。

新的路径设计为：

```text
配置目录: /data/docker/config/komf
漫画目录: /data/media/manga
端口: 8085
Komga 地址: http://komga:25600
```

一开始创建 Komf 的 Compose stack 后，服务一直重启。

第一个关键错误是：

```text
NoSuchFileException: /config/application.yml
```

这说明 Komf 不会自动生成默认配置文件，而是必须提供 `/config/application.yml`。

于是我增加了 `application.example.yml` 模板，并在运行目录中复制为：

```text
/data/docker/config/komf/application.yml
```

修复后，Komf 继续报错：

```text
komgaUser is invalid: Unexpected null or empty value
```

这说明 Komf 的配置解析器非常严格，`komgaUser` 和 `komgaPassword` 不能为空。于是我在本地运行时配置中填入 Komga 的管理员账号和密码。

继续启动后，又出现新的错误：

```text
kavita.baseUri is invalid: Unexpected null or empty value
```

虽然我并不使用 Kavita，但 Komf 的配置结构中仍然要求 `kavita.baseUri` 这类字段不能是空值。

最后的处理方式是：给 Kavita 相关字段填入不会实际使用的占位值，并保持：

```yaml
eventListener:
  enabled: false
```

最终 Komf 不再重启，访问：

```text
http://127.0.0.1:8085
```

返回 Ktor 的：

```text
404 Not Found
```

这不是故障，而是说明 Komf 服务已经监听端口，只是根路径没有页面或接口。

同时在 Komf 容器内部访问 Komga：

```text
http://komga:25600
```

能够得到 `HTTP/1.1 200`，说明 Docker 内部网络连通正常。

这次排查留下的经验是：

```text
有些服务不是只靠环境变量就能跑
必须认真处理配置文件
示例配置里的空值也可能导致程序启动失败
公开模板不能放真实密钥，但也不能放会导致启动失败的空值
排查时优先看日志里的第一个关键异常
```

## 追番工具选择

原本计划迁移 AutoBangumi，但推进到这一阶段时，我重新考虑了追番自动化工具的选择。

AutoBangumi 是成熟的 RSS 自动追番工具，但新的系统目标已经变化：

```text
不是完整迁移旧服务
而是重新设计追番自动化链路
```

所以这次暂时不迁移旧 AutoBangumi，改为部署 ANI-RSS。

新的追番链路变成：

```text
ANI-RSS
  -> qBittorrent
  -> /data/media/anime
  -> Jellyfin
```

也就是说，ANI-RSS 不再是孤立服务，而是 qBittorrent 的上层任务来源。

## qBittorrent

部署 ANI-RSS 前，先部署 qBittorrent。

这次 qBittorrent 不使用旧 PVE 上的 host 网络模式，而是加入 `homelab` Docker 网络，并显式映射端口：

```text
WebUI/API: 8080
BT TCP: 6881
BT UDP: 6881
```

新的路径设计为：

```text
配置目录: /data/docker/config/qbittorrent
下载工作区: /data/downloads
番剧媒体库: /data/media/anime
电影媒体库: /data/media/movie
漫画媒体库: /data/media/manga
```

分类设计为：

| 分类 | 完成目录 | 不完整下载目录 |
| --- | --- | --- |
| `ani-rss` | `/data/media/anime` | `/data/downloads/incomplete/ani-rss` |
| `radarr` | `/data/downloads/radarr` | `/data/downloads/incomplete/radarr` |
| `manual` | `/data/downloads/manual` | `/data/downloads/incomplete/manual` |
| `temp` | `/data/downloads/temp` | `/data/downloads/incomplete/temp` |

这样 qBittorrent 就成为统一下载底座，而不是某个单一服务的附属容器。

## ANI-RSS

qBittorrent 基础设置完成后，部署 ANI-RSS。

ANI-RSS 的路径挂载需要和 qBittorrent 保持一致，因此容器内也使用相同路径：

```text
/data/media/anime
/data/media/movie
```

这样 ANI-RSS 推送给 qBittorrent 的保存路径，在 ANI-RSS 容器、qBittorrent 容器和宿主机上语义一致，避免路径错乱。

ANI-RSS 的 qBittorrent 地址使用 Docker 内部服务名：

```text
http://qbittorrent:8080
```

而不是宿主机 IP。

这个原则后面也继续沿用：

```text
容器之间通信优先使用 Docker 服务名
浏览器访问才使用宿主机 IP
```

## Jellyfin

随后部署 Jellyfin。

Jellyfin 只负责视频媒体库：

```text
Anime  -> /data/media/anime
Movies -> /data/media/movie
```

音乐交给 Navidrome：

```text
Navidrome -> /data/media/music
```

Jellyfin 的媒体目录采用只读挂载：

```text
/data/media/anime:ro
/data/media/movie:ro
```

这样可以避免 Jellyfin 修改媒体文件，或者在 NAS 目录中写入元数据文件。Jellyfin 自己的元数据、缓存和配置留在自己的配置目录中。

初始化媒体库时：

| 媒体库 | 类型 |
| --- | --- |
| Anime | 节目 |
| Movies | 电影 |

高级选项没有过度调整。当前目标是先让媒体库扫描链路跑通，而不是马上把刮削、插件、硬件转码全部调到完美。

## Radarr

完成视频媒体库后，继续部署 Radarr。

Radarr 的路径设计为：

```text
配置目录: /data/docker/config/radarr
电影媒体库: /data/media/movie
下载工作区: /data/downloads
端口: 7878
```

新版 Radarr 初始化时已经强制要求配置认证。这里选择启用网页登录认证，而不是关闭认证：

```text
Authentication Method: Forms
Authentication Required: Enabled
```

创建账号密码后，可以在 Radarr 中看到 API Key。

随后配置 Radarr：

```text
Root Folder: /data/media/movie
Download Client: qBittorrent
Host: qbittorrent
Port: 8080
Category: radarr
```

这里同样使用 Docker 服务名 `qbittorrent`，而不是宿主机 IP。

## Prowlarr 接入 Radarr

Prowlarr 前面已经迁移完成，这一阶段把它接入 Radarr。

在 Prowlarr 中添加 Radarr 应用：

```text
Radarr Server: http://radarr:7878
Prowlarr Server: http://prowlarr:9696
API Key: Radarr 中复制的 API Key
Sync Level: Full Sync
```

终端中测试容器内部连通性时看到：

```text
Radarr -> qBittorrent : HTTP 200 OK
Radarr -> Prowlarr    : HTTP 401 Unauthorized
Prowlarr -> Radarr    : HTTP 401 Unauthorized
```

这里的 `401 Unauthorized` 是正常的，因为服务已经连通，只是接口需要认证或 API Key。

真正需要警惕的是这些错误：

```text
Could not resolve host
Connection refused
Connection timed out
```

这些都没有出现，说明 Docker 内部网络链路正常。

## 当前自动化链路

到这一阶段，新媒体自动化链路已经基本成型。

番剧链路：

```text
ANI-RSS
  -> qBittorrent category: ani-rss
  -> /data/media/anime
  -> Jellyfin Anime
```

电影链路：

```text
Prowlarr
  -> Radarr
  -> qBittorrent category: radarr
  -> /data/downloads/radarr
  -> Radarr import
  -> /data/media/movie
  -> Jellyfin Movies
```

音乐链路：

```text
Navidrome
  -> /data/media/music
```

漫画链路：

```text
Suwayomi
  -> /data/media/manga
  -> Komga
  -> Komf
```

这些服务都围绕统一路径和统一 Docker 网络组织起来，不再像旧 PVE 环境那样路径分散、职责混杂。

## 当前服务清单

截至这一阶段，`infra-docker-01` 上已经运行或完成基础配置的服务包括：

| 服务 | 地址 |
| --- | --- |
| Dockge | `192.168.3.30:5001` |
| FlareSolverr | `192.168.3.30:8191` |
| Prowlarr | `192.168.3.30:9696` |
| Sun Panel | `192.168.3.30:3002` |
| Navidrome | `192.168.3.30:4533` |
| Komga | `192.168.3.30:25600` |
| Suwayomi | `192.168.3.30:4567` |
| Komf | `192.168.3.30:8085` |
| qBittorrent | `192.168.3.30:8080` |
| ANI-RSS | `192.168.3.30:7789` |
| Jellyfin | `192.168.3.30:8096` |
| Radarr | `192.168.3.30:7878` |

## 经验总结

这一阶段最重要的不是部署了多少服务，而是几个原则逐渐稳定下来。

第一，所有服务都围绕标准路径设计：

```text
/data/docker/config
/data/docker/cache
/data/downloads
/data/media
```

第二，容器之间通信尽量使用 Docker 服务名：

```text
http://qbittorrent:8080
http://radarr:7878
http://prowlarr:9696
http://komga:25600
```

第三，下载器要作为基础设施，而不是某个服务的附属组件。

第四，媒体库服务尽量只读挂载媒体目录，避免直接写入 NAS 媒体目录。

第五，复杂服务先跑通基础功能，再考虑迁移旧配置或做高级联动。

第六，遇到服务启动失败时，优先看日志中的第一个关键异常。Komf 的排查就是典型案例：先缺配置文件，再是空账号字段，再是 Kavita 占位字段，逐层解决。

## 后续计划

下一步可以继续做几件事：

```text
部署 PeerBanHelper，接入 qBittorrent
给 homelab-compose 仓库补充服务清单文档
给下载链路补充 download-workflow.md
整理 Sun Panel 首页入口
再考虑是否迁移 Jenkins、RustFS、OpenResty 等更重的服务
后续把这些经验抽象进 Astralith 的设计中
```

到这个阶段，新主机已经不只是“能跑 Docker 服务”，而是初步形成了一套可维护、可扩展、可文档化的 homelab 媒体自动化平台。
