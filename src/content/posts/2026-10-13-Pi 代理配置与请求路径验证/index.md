---
title: "Pi 代理配置与请求路径验证"
urlSlug: "pi-http-proxy-request-verification"
published: 2026-10-13
description: "记录 macOS 上 Pi 1.2.0 仅有 all_proxy 仍然直连的排查：使用 agent 设置中的 httpProxy，并同时核对原生请求结果与连接路径。"
image: ''
author: "杨与S8"
tags: ["Pi", "macOS", "HTTP", "代理", "故障排查"]
category: "网络与代理"
draft: false
lang: 'zh_CN'
---

2026 年 10 月 13 日，在 macOS 上使用 Pi 1.2.0 时，终端里已有小写的 `all_proxy`，本地代理也正在监听，但 Pi 的原生启动探针仍然直连。最后只在 agent 设置里增加了 `httpProxy`，没有改安装文件或启动脚本。

## 找到 agent 的配置入口

[Pi 1.2.0 的设置参考](https://github.com/earendil-works/pi/blob/v1.2.0/packages/coding-agent/docs/settings.md#network-and-retries)列出了 `httpProxy`：它为 Pi 管理的 HTTP 客户端设置 `HTTP_PROXY` 和 `HTTPS_PROXY`，只接受 agent 目录中的设置。

默认文件是 `~/.pi/agent/settings.json`。如果通过 `PI_CODING_AGENT_DIR` 或 SDK 的 `agentDir` 指定了目录，就要修改那个目录下的文件，不能把字段写进项目的 `.pi/settings.json`。[配置目录说明](https://github.com/earendil-works/pi/blob/v1.2.0/packages/coding-agent/docs/configuration.md#agent-directory)区分了这两个入口。

## 增加一个字段

当时先备份原设置，再把下面的字段合并进去，其他设置保留：

```json
{
  "httpProxy": "http://127.0.0.1:PORT"
}
```

`PORT` 是占位符，替换成本机代理的 HTTP 监听端口；这段示例也不应覆盖已有的完整配置。代理软件如果提供多个入口，要核对监听协议和端口。

## 用 Pi 自己的请求验证

当时的原生启动探针记录如下：

| 配置 | 请求与连接观察 |
| --- | --- |
| 仅有小写 `all_proxy` | Pi 仍直接连接公网目标 |
| agent 设置增加 `httpProxy` | 返回 HTTP 200，连接指向本地代理 |

响应结果和连接去向要在同一次请求里核对。前者说明请求完成，后者才说明 Pi 采用了指定代理；其他工具能访问目标，不能替代这一步。

这次结果只覆盖当时 Pi 1.2.0 在 macOS 上的启动探针，本文没有重新运行，也没有验证所有模型服务、扩展或子进程。修改后如果仍然直连，先核对实际 agent 目录和进程是否载入新设置；已经连到代理却请求失败，再检查代理到目标服务这一段。
