---
title: "Hermes 单网关与历史会话迁移"
urlSlug: 'hermes-single-gateway-history-migration'
published: 2026-09-15
description: '把已有 Hermes profile 提升为 default 并收敛到单网关，保留历史会话与路由，同时修复桌面入口对旧 profile 的引用。'
image: ''
author: ""
tags: ['Hermes', 'SQLite', 'systemd', '数据迁移', '故障排查', '实战记录']
category: 'AI Agent 工作流'
draft: false
lang: 'zh_CN'
---

9 月 15 日，我把日常使用的 Hermes profile 提升为内置 `default`，再把多个 profile 收敛到一个 multiplex gateway。迁移后，历史消息校验一致，聊天路由保持原来的会话，网关也正常运行。但桌面程序第一次启动仍然失败：它自己的配置还指向旧 profile。

本文根据当天的迁移记录事后整理。原主 profile 在文中记为 `assistant`，另外两个记为 `worker-a`、`worker-b`；这些名称及代码中的文件名是匿名化示例。

## 先分清两个迁移目标

Hermes 的 profile 是一套独立的配置与数据目录。模型、记忆、历史会话和定时任务都可能属于这个目录，不能把它只当作启动命令的一个参数。官方 [Profiles 文档](https://hermes-agent.nousresearch.com/docs/user-guide/profiles/) 介绍了这层隔离。

这次我需要做两件事：让原来的 `assistant` 成为默认身份，以及让一个网关进程托管多个 profile。按当时安装版本的实现，multiplex gateway 的管理入口是内置 `default`。网关迁移命令能整理服务和开启复用，却不能直接表达“把这个已有 profile 的身份和历史提升为 default”。

如果先创建一个空 default，再启动单网关，进程可能能跑，但原来的会话、记忆和定时任务仍留在另一套目录里。因此实际顺序是先完成数据提升，再做网关收敛。

迁移前的预检还发现，其他 profile 保留了重复的机器人凭据，官方 dry-run 因此拒绝继续。最终只清理重复的聊天平台凭据，保留它们各自的模型与其他配置。这里的目标是确定平台连接的归属，不能为了通过检查把整个 profile 配置删掉。

## 备份要同时覆盖数据和启动入口

这次备份包含原主 profile、将被替换的 default 文件、其他 profile 中会修改的配置，以及旧服务、命令别名和活动 profile 选择器。随后停止旧网关并卸载对应服务，再执行受控迁移。

历史会话并不只靠复制数据库文件保持连续。实际迁移还处理了这些引用：

- 会话表中的 profile 所有权改为 `default`，保留原来的会话 ID、会话标识及消息关联。
- 路由索引中的目录作用域改到新的会话目录，让已有聊天仍找到原会话。
- 符号链接和定时任务中的旧绝对路径同步调整，定时任务原有的启停状态保留。
- 命令别名指向 `hermes -p default`，显示名称继续沿用原来的身份。

这些修改各有自己的验证条件。只检查“文件已经复制过去”，看不出路由是否仍指向旧目录，也看不出一个相对软链接移动后是否改变了含义。

迁移前需要暂停写入并保留完整备份，再检查当前安装版本、profile 状态、表结构和已有 default 数据，确定迁移范围。

## 用内容与身份校验历史

迁移后的行数与迁移前一致，这是第一层检查。第二层检查保留会话 ID 和会话标识，确认关联没有被重新生成。第三层对全部消息行按固定顺序计算摘要，迁移前后的摘要一致；身份说明与主要记忆文件也逐字节比对。

下面用离线副本演示消息摘要比较（简化示例）：

```python
import hashlib
import json
import sqlite3

def message_digest(connection):
    digest = hashlib.sha256()
    for row in connection.execute("SELECT * FROM messages ORDER BY id"):
        payload = json.dumps(
            row,
            ensure_ascii=False,
            separators=(",", ":"),
            default=lambda value: {"bytes": value.hex()},
        )
        digest.update(payload.encode("utf-8"))
        digest.update(b"\n")
    return digest.hexdigest()

# 两个文件均为离线副本；实际使用前先确认表结构一致。
before = sqlite3.connect("file:demo-before.db?mode=ro", uri=True)
after = sqlite3.connect("file:demo-after.db?mode=ro", uri=True)
assert message_digest(before) == message_digest(after)
before.close()
after.close()
```

`ORDER BY id` 和固定序列化方式是为了让两次摘要可比较。二进制字段也要处理，否则 JSON 序列化会失败；当天的校验脚本就补过这一项。SQLite 的只读 URI 用法见 [官方 URI 文档](https://www.sqlite.org/uri.html)。这里只读副本，避免把验证代码变成新的写入来源。

摘要一致仍不能单独证明聊天入口可用。当天还检查了当前聊天的路由目标，并通过带认证的历史接口读取原会话和非空消息记录，响应为 HTTP 200。

## 网关正常，桌面入口仍可能用旧状态

完成数据提升后，再用官方网关迁移流程开启 multiplex，最终由一个用户级 systemd 服务托管 default 和另外两个 profile。当天的运行状态显示聊天平台及本地 API 已连接，旧的独立网关服务被移除。

随后桌面程序启动失败，提示旧 profile 不存在。此时 CLI 别名和网关已经指向 default，继续重复迁移它们没有作用。问题在于 Desktop 独立持久化了活动 profile：它保存的旧名字会作为本地后端的启动参数，覆盖已经修正的命令行状态。

补修时先备份桌面选择器，再把其中的 profile 原子更新为 `default`。随后实际启动现有桌面程序，后端成功公布端口，并通过 WebSocket 鉴权探测。带认证的 profile 接口确认活动与当前 profile 均为 default，历史会话接口返回 HTTP 200，也没有再出现端口公布前退出的错误。

这次遗漏使验收范围变得很明确：profile 的数据目录、CLI 活动状态、命令别名、systemd 服务、桌面选择器和连接缓存都可能保存引用。迁移清单应按入口逐项检查，桌面应用要实际启动一次。

## 已完成的验证与回退范围

当天确认了历史内容与会话身份一致、原聊天路由连续、单网关运行，以及桌面后端和历史接口可用。没有向聊天平台发送测试消息，也没有调用模型生成回复，因此完整的新消息收发回合仍需单独验证，不能用“connected”替代这项结果。

回退也有两层。`hermes gateway migrate --standalone` 处理的是网关复用模式，不会撤销 profile 提升、数据库所有权和路径修改。恢复原来的数据布局，需要配合数据及启动控制文件的备份；若迁移后已经产生新消息，还要先停写并处理新旧数据的归属，不能直接用旧备份覆盖。

这次迁移最容易遗漏的地方已经写进后续检查项：历史内容要比对，已有路由要读取，桌面入口要启动。服务状态只能证明对应的那一层。
