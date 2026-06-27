---
title: "Dockge Compose 管理体系"
urlSlug: 'dockge-compose-management-workflow'
published: 2026-06-28
description: '记录 PVE 服务分层迁移后的第三阶段：在 infra-docker-01 上用 Git 管理标准 Compose，用 Dockge 作为本地操作面板，并标准化部署 FlareSolverr、Prowlarr 和 Sun Panel。'
image: ''
author: ""
tags: ["Docker", "Docker Compose", "Dockge", "Git", "Homelab", "PVE", "实战记录"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这是 PVE 服务整理的第三篇记录。

前两篇主要完成了底座：先把 PVE 宿主机上的职责重新分层，再单独部署 `net-gateway-01` 作为旁路代理网关。

- [PVE 服务分层迁移记录](/posts/pve-service-layering-migration/)
- [OpenWrt 旁路代理网关部署](/posts/openwrt-sidecar-proxy-gateway/)

这一篇继续往下走，但不是直接把所有服务一口气搬走，而是先把 Compose 管理方式整理出来。

最终目标是：

```text
Git 仓库保存标准 Compose
Dockge 作为本机可视化操作面板
运行目录保存真实 .env 和实际部署文件
服务数据统一放到 /data/docker
```

这样后续迁移 Jellyfin、Navidrome、Komga、qBittorrent、Radarr 这些更重的服务时，不会把 PVE 上的历史混乱一起搬过去。

## 当前目标

在前一阶段结束时，`infra-docker-01` 已经能正常运行 Docker，并且可以通过 `net-gateway-01` 访问 Docker Hub。

这一阶段要解决的问题变成了：

```text
Compose 文件放在哪里
Dockge 管理哪些目录
真实 .env 怎么保存
哪些内容可以进公开 Git 仓库
服务配置和数据怎么统一放置
第一个标准化服务如何落地
```

这次不追求迁移数量，而是先把流程跑通。

## 设计原则

这次没有继续沿用 1Panel 的目录结构，也没有让 Dockge 成为唯一配置来源。

最后确定的关系是：

```text
Git 仓库 = Compose 配置资产中心 / Source of Truth
Dockge = 每台 Docker 主机上的本地操作面板
Docker Compose = 原生运行格式
未来自研平台 = 读取 Git，再调用 Docker / SSH / API
```

这里最关键的是第一行：**Git 才是事实来源**。

Dockge 很适合做本机可视化管理，可以启动、停止、查看日志，也能直接编辑 stack。但如果所有配置只留在 Dockge 的运行目录里，后面换面板、扩展多服务器、做备份和审计都会比较难受。

所以我更希望每个服务都整理成一个标准 Stack：

```text
stacks/<service>/compose.yaml
stacks/<service>/.env.example
stacks/<service>/README.md
```

真实运行时再放到：

```text
/data/compose/stacks/<service>/compose.yaml
/data/compose/stacks/<service>/.env
```

这样即使用不上 Dockge，也可以直接进入目录执行：

```bash
docker compose config
docker compose up -d
```

## 节点与存储

新的 Docker 服务节点仍然是：

```text
Hostname: infra-docker-01
IP: 192.168.3.30
系统: Debian GNU/Linux 13 trixie
虚拟化: KVM
内存: 约 12G
```

这台 VM 有系统盘和数据盘。这里有一个重要修正：一开始考虑过把 Docker Engine 的数据目录迁到 `/data/docker-engine`，但后来确认 `/data` 是机械硬盘，所以放弃了这个方案。

最终规划是：

```text
/var/lib/docker      保持默认，继续放在系统盘
/data/compose        放 compose 文件、Git 仓库、Dockge stacks
/data/docker         放应用配置、数据、缓存、备份
/data/media          后续作为媒体挂载入口
```

原因很直接：Docker 的 `overlay2`、镜像层、容器可写层、日志和小文件随机 IO 比较多，不适合整体放到机械硬盘上。

机械硬盘更适合放这些内容：

```text
媒体文件
下载文件
应用配置
低频数据
备份文件
```

而不是 Docker Engine 的运行层。

## 目录结构

最终在 `infra-docker-01` 上整理出的目录结构是：

```text
/data/
├── compose/
│   ├── stacks/        # Dockge 实际管理的运行目录
│   └── repo/          # Git 仓库目录
│
├── docker/
│   ├── config/        # 服务配置
│   ├── data/          # 应用数据
│   ├── cache/         # 缓存
│   └── backups/       # 备份
│
└── media/
    ├── anime/
    ├── movie/
    ├── music/
    └── manga/
```

几个路径的职责要分清楚：

| 路径 | 用途 |
| --- | --- |
| `/data/compose/stacks` | Dockge 管理和运行 stack 的目录 |
| `/data/compose/repo/homelab-compose` | Git 仓库工作目录 |
| `/data/docker/config/<service>` | 服务配置目录 |
| `/data/docker/data/<service>` | 服务数据目录 |
| `/data/docker/cache/<service>` | 缓存目录 |
| `/data/docker/backups` | 后续备份目录 |

这样以后看一个服务时，基本可以按同一个模式找：

```text
Compose 标准版：/data/compose/repo/homelab-compose/stacks/<service>
Compose 运行版：/data/compose/stacks/<service>
配置和数据：/data/docker/config/<service>
```

## 部署 Dockge

Dockge 被作为第一个 stack 部署在：

```text
/data/compose/stacks/dockge
```

挂载的关键内容是：

```text
/var/run/docker.sock
/data/compose/stacks
/data/docker/config/dockge
```

对外端口：

```text
http://192.168.3.30:5001
```

启动后容器状态正常：

```text
dockge    louislam/dockge:1    Up    healthy
```

日志里也能看到：

```text
Welcome to dockge!
Connected to the database
No user, need setup
Listening on 5001
```

这说明 Dockge 已经可以作为 `infra-docker-01` 本机的 Compose 管理面板使用。

这里也要注意一点：Dockge 需要挂载 Docker socket，意味着它对本机 Docker 有很高权限，所以不应该直接暴露到公网。

## 创建 homelab-compose 仓库

为了让 Compose 配置可以长期维护，我在 `infra-docker-01` 上创建了：

```text
/data/compose/repo/homelab-compose
```

仓库骨架如下：

```text
homelab-compose/
├── docs/
│   ├── hosts.md
│   ├── networks.md
│   └── storage.md
├── hosts/
│   ├── infra-docker-01/
│   │   └── stacks/
│   ├── net-gateway-01/
│   └── pve/
│       └── stacks/
├── scripts/
├── stacks/
│   └── dockge/
│       ├── compose.yaml
│       └── README.md
├── templates/
│   ├── compose.template.yaml
│   └── env.example
├── .gitignore
└── README.md
```

几个目录的用途：

| 目录 | 用途 |
| --- | --- |
| `docs/` | 记录主机、网络和存储规划 |
| `hosts/` | 预留按主机组织的配置入口 |
| `stacks/` | 保存标准化后的公开 compose |
| `templates/` | 保存通用模板 |
| `scripts/` | 保存部署、检查等辅助脚本 |

这个仓库未来准备开源，所以从一开始就不能把真实密钥、真实 `.env`、原始 PVE compose 或未脱敏配置放进去。

## 开源安全边界

一开始我考虑过把 PVE 上的原始 Compose 做一份 `raw-stacks` 快照放进仓库，方便后续参考。后来这个方案被否掉了。

原始 Compose 里可能存在：

```text
硬编码密钥
token
access key / secret key
真实内网路径
真实服务端口
代理地址
私有域名
下载器、索引器、对象存储等敏感配置
```

如果仓库未来要公开，这些内容不能混进去。

最后的边界是：

```text
公开仓库：
  只放脱敏后的标准 compose、README、.env.example、模板和脚本

真实运行目录：
  放本机 .env 和实际 compose

私有快照目录：
  放在仓库外，例如 /data/compose/private，不进入 Git
```

同时 `.gitignore` 里排除：

```text
.env
*.env
*.secret
secrets/
private/
raw/
raw-stacks/
hosts/**/raw-stacks/
*.local.yml
*.raw.yml
```

这一步比多迁移几个服务更重要。因为它决定了这个仓库以后能不能安全公开、能不能被长期维护。

## 标准版与运行版分离

整理后，每个服务会同时存在两个形态。

Git 仓库里的标准版：

```text
/data/compose/repo/homelab-compose/stacks/<service>/compose.yaml
/data/compose/repo/homelab-compose/stacks/<service>/.env.example
/data/compose/repo/homelab-compose/stacks/<service>/README.md
```

运行目录里的实际版本：

```text
/data/compose/stacks/<service>/compose.yaml
/data/compose/stacks/<service>/.env
```

服务数据统一放到：

```text
/data/docker/config/<service>
/data/docker/data/<service>
/data/docker/cache/<service>
```

这样有几个好处：

1. Git 里可以安全保存标准模板；
2. `.env` 留在本机，不进入公开仓库；
3. Dockge 可以管理 `/data/compose/stacks`；
4. 不依赖 Dockge 的私有结构；
5. 后续可以用脚本或自研平台读取 Git，再部署到不同主机。

## 部署脚本

为了减少手工复制文件，我写了一个辅助脚本：

```text
scripts/deploy-stack.sh
```

使用方式：

```bash
./scripts/deploy-stack.sh <stack-name>
```

它主要做三件事：

1. 从 Git 仓库的 `stacks/<stack-name>` 复制 `compose.yaml` 到 `/data/compose/stacks/<stack-name>`；
2. 如果运行目录没有 `.env`，就从 `.env.example` 创建；
3. 不自动启动服务，只提示下一步执行 `docker compose config` 和 `docker compose up -d`。

这里故意不自动启动服务。

因为部署脚本应该先帮我减少重复动作，而不是替我跳过确认步骤。尤其是这种自托管服务迁移，启动前最好先检查一次最终 Compose：

```bash
docker compose config
```

确认没有路径、端口、变量问题后，再启动：

```bash
docker compose up -d
```

## 第一个样板：FlareSolverr

第一个标准化服务选择 `flaresolverr`。

原因是它足够简单：

```text
基本无状态
不涉及媒体库
不涉及下载路径
不需要复杂联动
适合验证 Git + Dockge + Compose 工作流
```

路径规划：

```text
Git 仓库：/data/compose/repo/homelab-compose/stacks/flaresolverr
运行目录：/data/compose/stacks/flaresolverr
配置目录：/data/docker/config/flaresolverr
```

运行端口：

```text
192.168.3.30:8191
```

旧 PVE 上的 FlareSolverr 使用过类似这样的代理地址：

```text
PROXY=http://172.18.0.1:20172
```

这类地址绑定的是 PVE 上的 Docker bridge，不适合照搬到新节点。

新的标准化版本改为通过 `.env` 配置：

```text
FLARESOLVERR_PROXY=http://192.168.3.20:7890
```

也就是让它走 `net-gateway-01` 提供的显式代理。

启动后日志显示：

```text
FlareSolverr 3.5.0
Testing web browser installation...
Chrome / Chromium path: /bin/chromium
Test successful!
Serving on http://0.0.0.0:8191
```

测试返回：

```text
HTTP/1.1 200 OK
```

这说明第一个标准化服务已经在新节点上跑通。

## 第二个样板：Prowlarr

第二个服务选择 `prowlarr`。

它比 Jellyfin、qBittorrent、Radarr 更轻，只需要先处理 `/config`，不直接涉及大容量媒体目录。

路径规划：

```text
Git 仓库：/data/compose/repo/homelab-compose/stacks/prowlarr
运行目录：/data/compose/stacks/prowlarr
配置目录：/data/docker/config/prowlarr
```

运行端口：

```text
192.168.3.30:9696
```

启动后容器状态正常：

```text
prowlarr   lscr.io/linuxserver/prowlarr:latest   Up
```

日志显示：

```text
Now listening on: http://[::]:9696
Application started.
Hosting environment: Production
```

本机测试：

```bash
curl -I http://127.0.0.1:9696
```

返回：

```text
HTTP/1.1 401 Unauthorized
```

这里的 `401` 不是错误，而是 Prowlarr 的认证机制在工作。服务已经监听端口，只是访问 Web 或 API 需要认证。

到这一步，我也确定了一个后续原则：**大多数旧服务不再完整迁移旧配置，而是在新环境中重新配置**。

旧配置里有不少历史路径、代理地址和临时改动，强行迁移容易把问题一起带过去。既然这次本来就是整理，就不如借机会把配置重新规范化。

## 第三个样板：Sun Panel

第三个服务选择 `sun-panel`。

它不涉及媒体库，也不依赖下载器和索引器联动，适合作为第三个干净服务样板。

路径规划：

```text
Git 仓库：/data/compose/repo/homelab-compose/stacks/sun-panel
运行目录：/data/compose/stacks/sun-panel
配置目录：/data/docker/config/sun-panel
```

运行端口：

```text
192.168.3.30:3002
```

这个服务有一个特殊点：它挂载了 Docker socket。

```text
/var/run/docker.sock
```

这意味着它访问的是 `infra-docker-01` 本机 Docker，而不是 PVE 上的 Docker。这个行为符合新规划，因为现在要管理的是新 Docker 节点上的服务。

但同样需要注意：挂载 Docker socket 的服务权限很高，不应该直接暴露到公网。

目前 `sun-panel` 已经正常运行。

## 当前成果

这一阶段完成后，`infra-docker-01` 上已经有四个服务按新方式运行：

| 服务 | 地址 | 状态 |
| --- | --- | --- |
| Dockge | `http://192.168.3.30:5001` | healthy |
| FlareSolverr | `http://192.168.3.30:8191` | 正常 |
| Prowlarr | `http://192.168.3.30:9696` | 正常，访问需认证 |
| Sun Panel | `http://192.168.3.30:3002` | 正常 |

同时也完成了这些基础工作：

```text
1. 确定 Git 作为 Compose Source of Truth
2. 确定 Dockge 只作为本地操作面板
3. 规划 /data/compose、/data/docker、/data/media
4. 建立 homelab-compose 仓库骨架
5. 明确公开仓库和真实运行配置的边界
6. 编写 deploy-stack.sh 辅助部署脚本
7. 标准化 FlareSolverr、Prowlarr、Sun Panel 三个服务
```

这次维护的重点不是“又多跑了几个容器”，而是 Compose 管理方式变清楚了。

以前是：

```text
服务散落在 PVE 宿主机
1Panel 与手写 Compose 混用
路径和网络配置不统一
代理地址硬编码
配置来源不清楚
```

现在变成：

```text
Git 保存标准 Compose
Dockge 管理本机运行目录
.env 留在本机
配置和数据进入统一目录
每个服务都可以单独部署、停止、重建
```

这对后续迁移更重要。因为后面的服务会更麻烦：媒体库、下载目录、硬链接、对象存储、反向代理、硬件转码都会逐步出现。

如果没有先把管理体系整理好，后面每迁一个服务都会继续扩大混乱。

## 后续计划

下一阶段仍然不建议一口气全搬。

比较适合继续处理的顺序是：

```text
1. Navidrome
2. Komga
3. Suwayomi
4. Radarr
5. qBittorrent
6. AutoBangumi
7. Jellyfin
8. RustFS
9. Jenkins
10. OpenResty / 入口层
```

其中需要特别谨慎的是：

| 服务 | 风险点 |
| --- | --- |
| qBittorrent | 下载路径、端口、host 网络、硬链接 |
| Radarr | 媒体路径、下载器联动 |
| Jellyfin | 媒体库、硬件转码 |
| RustFS | 对象存储数据 |
| OpenResty | 入口流量，不适合太早迁移 |

后续原则还是保持不变：

```text
先让服务干净跑起来
再重新配置
不强行迁移旧配置
不把敏感信息写入 Git
不急着停掉 PVE 上旧服务
```

到这里，PVE 服务迁移已经从“建新 VM”和“解决网络”进入到“整理服务资产”的阶段。

这一步看起来没有直接迁移重服务，但它决定了后续每个服务能不能按同一套方式落地。对家用服务器来说，能跑只是第一步，能长期维护才是更重要的部分。
