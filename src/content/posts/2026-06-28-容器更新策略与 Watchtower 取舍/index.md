---
title: "容器更新策略与 Watchtower 取舍"
urlSlug: 'homelab-container-update-policy-watchtower'
published: 2026-06-28
description: '记录 PVE 服务整理后的第四阶段：在 infra-docker-01 上评估 Watchtower 自动更新方案，最终放弃无人值守更新，改用中立更新策略标签，为未来 Astralith 平台保留可控更新能力。'
image: ''
author: ""
tags: ["Docker", "Docker Compose", "Watchtower", "Homelab", "Astralith", "PVE", "实战记录"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这是 PVE 服务整理的第四篇记录。

前面几篇已经完成了基础分层、旁路网关和新的 Compose 管理底座：

- [PVE 服务分层迁移记录](/posts/pve-service-layering-migration/)
- [OpenWrt 旁路代理网关部署](/posts/openwrt-sidecar-proxy-gateway/)
- [Dockge Compose 管理体系](/posts/dockge-compose-management-workflow/)

到这一阶段，`infra-docker-01` 已经有了 Dockge、Git 仓库和标准化 Compose 目录。接下来遇到的问题是：容器服务到底要不要自动更新。

我的结论是：

```text
不引入 Watchtower
不做无脑自动更新
保留中立更新策略
把真正的更新编排能力留给未来的平台
```

这里记录的是这次取舍过程。

## 当前背景

新的 Docker Compose 主机已经建立了基础管理方式：

```text
Git 仓库: /data/compose/repo/homelab-compose
运行目录: /data/compose/stacks
服务配置: /data/docker/config
媒体路径: /data/media
```

已经初步迁移和标准化的轻量服务包括：

```text
Dockge
FlareSolverr
Prowlarr
Sun Panel
```

这些服务迁移完成后，我开始考虑更新策略。

自动更新看起来很有吸引力：可以及时拿到安全修复，也能避免服务长期停留在旧镜像。但落到 homelab 里，问题并不只是“开不开自动更新”。

真正需要回答的是：

```text
哪些服务能自动更新
哪些服务只能提醒
哪些服务必须人工确认
更新前是否备份
更新后如何健康检查
失败后能不能回滚
更新记录在哪里审计
```

如果这些问题没有设计清楚，自动更新就不是减少运维负担，而是在系统里放进一个不受控变量。

## 最初方案

一开始我考虑使用 Watchtower。

Watchtower 的模式很直接：监控正在运行的容器，发现镜像更新后自动拉取新镜像，然后重建容器。

为了避免它误更新所有服务，我原本准备采用白名单模式：

```text
只有显式打了更新标签的容器，才允许 Watchtower 自动更新。
```

当时准备使用的标签是：

```yaml
labels:
  com.centurylinklabs.watchtower.enable: "true"
```

服务更新风险大致分三类：

| 类型 | 策略 | 示例 |
| --- | --- | --- |
| 低风险服务 | 可以考虑自动更新 | FlareSolverr、简单 dashboard、临时工具 |
| 中风险服务 | 提醒更新，人工确认 | Prowlarr、Navidrome、Komga、Suwayomi |
| 高风险服务 | 只允许手动更新 | Jellyfin、qBittorrent、Dockge、OpenResty、Jenkins、RustFS、数据库 |

这个思路本身没有问题。真正的问题出现在实际部署 Watchtower 之后。

## 遇到的问题

Watchtower 部署后并没有正常稳定运行，而是不断重启。

日志里出现了类似这样的错误：

```text
client version 1.25 is too old. Minimum supported API version is 1.40
```

这说明 Watchtower 容器内部使用的 Docker API 客户端版本和宿主机 Docker daemon 不兼容。宿主机 Docker 版本比较新，而容器里的客户端 API 版本太旧，daemon 直接拒绝连接。

如果只是一次普通兼容问题，还可以继续换镜像版本、查 issue 或者临时调整。但后续我查看 `containrrr/watchtower` 仓库时，发现上游项目已经归档。

这就改变了问题性质。

对于临时测试环境，一个归档项目未必完全不能用。但这里要进入的是长期 homelab 标准化体系，不是随手跑一个容器试试看。

自动更新器本身会接触 Docker socket，并且会决定哪些容器被重建。它不是普通辅助服务，而是带有较高操作权限的基础设施组件。

所以我不希望把未来的更新能力绑定到一个已经没有维护承诺的项目上。

## 最终处理

最后我撤回了 Watchtower 方案。

具体处理包括：

```text
停止并删除不断重启的 Watchtower 容器
从 Git 仓库中移除 stacks/watchtower
移除 Watchtower 专属 label
放弃依赖某个具体自动更新器
保留更新策略这个设计
```

这里重要的不是“Watchtower 不好”，而是我不想为了自动更新本身牺牲系统的可控性。

对这个 homelab 来说，自动更新不是目标，可控更新才是目标。

## 中立更新标签

为了避免 Compose 配置绑定到 Watchtower，我把更新策略改成了自己的中立标签：

```yaml
labels:
  dev.nesoriel.update.policy: "manual"
```

目前规划三个值：

| 值 | 含义 |
| --- | --- |
| `auto` | 未来允许自动更新，但必须具备备份、健康检查和回滚能力 |
| `notify` | 只提醒有更新，不自动执行 |
| `manual` | 必须人工确认并手动更新 |

这个标签不依赖 Watchtower，也不依赖某个具体工具。它更像是给未来统一管理平台留下的元数据。

例如：

```yaml
labels:
  dev.nesoriel.update.policy: "notify"
```

表示这个服务可以被平台检测更新并提醒用户，但不应该直接无人值守重建。

再比如核心服务：

```yaml
labels:
  dev.nesoriel.update.policy: "manual"
```

表示更新前必须人工确认，必要时先看 release notes，再备份配置目录和数据目录。

## 服务分级

当前我按风险把服务分为三类。

### 低风险服务

这类服务通常无状态，或者可以很容易重建：

```text
FlareSolverr
简单 dashboard
临时工具类服务
```

它们未来可以考虑 `auto`，但前提不是“有新镜像就重启”，而是平台具备最基本的保护：

```text
更新前记录当前镜像
更新后做健康检查
失败时自动回滚
成功后记录变更日志
```

### 中风险服务

这类服务有自己的配置数据库，但不是整个系统的核心入口：

```text
Prowlarr
Radarr
Navidrome
Komga
Suwayomi
Komf
ANI-RSS
```

它们更适合 `notify`。

也就是说，平台可以告诉我有新版本，但真正更新前仍然需要人工确认。尤其是这类服务常常涉及数据库迁移，更新前至少应该知道新版本改了什么。

### 高风险服务

这类服务是核心入口、下载底座、反向代理、对象存储或 CI 系统：

```text
Jellyfin
qBittorrent
Dockge
OpenResty
Jenkins
RustFS
数据库
反向代理
对象存储
```

它们默认应该是 `manual`。

这些服务一旦更新失败，影响的不是单个页面，而是整个访问链路、媒体库、下载任务、构建任务或数据存储。

## 给 Astralith 的启发

这次取舍后来也被记录进 Astralith 的设计方向里。

我希望未来的 Astralith 不只是包装 Docker Compose，也不只是接一个类似 Watchtower 的自动更新器。真正需要的是一套可审计、可回滚、可控制的更新编排能力。

理想流程应该接近这样：

```text
检测镜像更新
↓
读取服务更新策略
↓
识别服务风险等级
↓
生成更新计划
↓
提示用户确认
↓
备份配置和关键数据
↓
拉取新镜像
↓
重建容器
↓
执行健康检查
↓
失败则回滚
↓
成功则记录变更日志
```

这样更新就不再是“看到新镜像就重启容器”，而是一个完整的运维动作。

中立标签的价值也在这里：现在的 Compose 文件先保留策略信息，将来无论 Astralith 通过 Docker API、SSH 还是其他方式执行更新，都可以读取这份元数据。

## 当前结论

这一阶段最后形成的原则是：

```text
Git 是 Source of Truth
Compose 文件保持标准化
运行时 .env 和真实凭据不进入公开仓库
服务是否允许自动更新由中立 label 描述
自动更新不是目标，可控更新才是目标
```

Watchtower 没有继续保留，但更新策略没有被删除。

这件事也提醒我：基础设施里很多决策不是“能不能跑起来”，而是“这个组件能不能成为未来架构的一部分”。

如果只是追求眼前可用，自动更新很容易变成一个黑盒动作。对长期维护的 homelab 来说，我更愿意慢一点，把更新能力留给一个能备份、能验证、能回滚、能审计的平台。

下一篇继续进入媒体服务迁移前的准备：NAS 挂载、媒体路径规划和下载底座设计。
