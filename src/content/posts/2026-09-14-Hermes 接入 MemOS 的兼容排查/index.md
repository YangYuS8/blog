---
title: "Hermes 接入 MemOS 的兼容排查"
urlSlug: 'hermes-memos-model-compatibility'
published: 2026-09-14
description: '一次 Hermes 与 MemOS 本地集成排障：沿调用链追踪遗漏的模型设置，处理动态主模型别名，并对齐 Python、TypeScript 和实际运行产物。'
image: ''
author: ""
tags: ['Hermes', 'MemOS', 'Python', 'TypeScript', '故障排查', '实战记录']
category: 'AI Agent 工作流'
draft: false
lang: 'zh_CN'
---

9 月 14 日处理 Hermes 接入 MemOS 时，问题出在模型设置的传递上：设置已经存在，但没有完整进入实际调用链。修复还涉及“跟随当前主模型”的动态别名，以及 Python 适配层、TypeScript 侧和运行产物之间的兼容。当天在本机部署了修复并完成回归。

本文根据当天的排障结果事后整理，配置与代码均使用简化示例。

## 配置保存成功，调用未必使用了它

接入外部记忆系统后，主对话和记忆处理会经过不同的调用路径。主对话能正常回复，只能证明主模型那条路径可用。不能由此推断记忆组件使用了同样的模型、provider 或设置。

这次已定位的断点是模型设置没有传入调用链。排查时需要沿着同一个值往下看：配置读取结果是什么，适配层接收到什么，跨进程消息带了什么，最终构造请求时又使用了什么。若只看配置界面的保存结果，很容易把参数遗漏误判成后端服务不兼容。

为说明这个区别，假设记忆组件有一段独立配置，下面的键名与模型名都属于示例：

```yaml
memory_llm:
  provider: example-provider
  model: example-model-a
```

一次完整的配置传递至少要让 `example-model-a` 到达构造模型请求的位置。中间层如果只转发处理任务，而没有转发模型选择，最上层显示的值与最下层实际使用的值就可能不同。

日志也应按这条路径设计。为了确认传播，可以记录选中的模型标识和调用阶段，但没有必要输出完整配置、认证信息或记忆正文。最终判定依据应是请求使用的非敏感参数，而不是页面上看到了某个值。

## 动态别名需要保留它的含义

另一个兼容点是动态主模型别名。它表达的是“使用当前 Agent 的主模型”，并不是模型服务端能够直接识别的固定模型 ID。

如果在设置时就把这个别名替换成一次性的模型名，之后切换主模型，记忆侧仍可能用旧值；如果完全不解析，又可能把内部别名当成模型 ID 往外发送。因此要先明确它由哪一层解析，以及解析时读取哪个 Agent 的模型状态。

示例用自定义别名 `agent-current` 表示“跟随当前主模型”。实际配置应使用当前版本支持的标识：

```python
def resolve_model(selection, current_model):
    if selection == "agent-current":
        return dict(current_model)
    return dict(selection)

def build_bridge_payload(selection, current_model):
    return {
        "model": resolve_model(selection, current_model),
        "task": "demo-memory-task",
    }

# 全部为合成配置，不会发出网络请求。
current = {"provider": "example-provider", "model": "example-model-a"}
payload = build_bridge_payload("agent-current", current)
assert payload["model"]["model"] == "example-model-a"

current["model"] = "example-model-b"
next_payload = build_bridge_payload("agent-current", current)
assert next_payload["model"]["model"] == "example-model-b"
```

这个例子只演示每次构造任务时的解析。真实集成还要遵循宿主的模型切换规则：新设置是立即生效还是下一轮生效，当前会话是否已有自己的模型覆盖，都需要按当时的调用上下文处理。不能从一个全局变量里取值，就假设它适用于所有 profile 和会话。

## Python、TypeScript 和运行产物要一起对齐

MemOS 的[本地插件公开说明](https://raw.githubusercontent.com/MemTensor/MemOS/main/apps/memos-local-plugin/README.md)列出了 Hermes 的 Python 适配器、JSON-RPC bridge 和 TypeScript 核心。这种结构意味着，一个参数可以在 Python 中存在，在跨进程边界遗漏，也可以到达 TypeScript 后才被旧逻辑忽略。

当天的兼容修复同时覆盖了 Python、TypeScript 和构建产物。进程实际加载的入口可能是打包后的 JavaScript，修改 `.ts` 文件后，还需要重新构建并更新运行产物。TypeScript 对输出目录的说明可见 [outDir 文档](https://www.typescriptlang.org/tsconfig/outDir.html)；具体项目是否用 `tsc`、bundler 或预构建包，则应查看它自己的构建脚本。

在这类集成中，我会按下面的边界核对，避免只修一端：

| 边界 | 需要确认的内容 |
| --- | --- |
| 配置到 Python | 模型选择被读取并进入适配层，动态别名没有提前变成过期的固定值 |
| Python 到 bridge | 消息携带必要字段，缺失值与显式选择的语义明确 |
| bridge 到模型请求 | TypeScript 侧理解同一份协议，实际请求使用预期的模型设置 |
| 源码到运行进程 | 启动入口、构建产物和已部署文件对应同一轮修复 |

Hermes 的 [Memory Provider Plugins 文档](https://hermes-agent.nousresearch.com/docs/developer-guide/memory-provider-plugin/)也把配置保存、初始化上下文和工具调用列为不同接口。核查新版本时要看各接口的当前契约，不能只凭旧配置字段猜测调用行为。

## 当天回归能说明什么

这次本地兼容修复已部署，并通过当日回归；没有对应的 Git 提交，上游发布状态未核实。重现时应先记录宿主版本、插件版本、构建方式和运行入口，再用合成内容验证。

当日回归验证了接口兼容，尚未评估长期检索质量、误召回率和调用成本。这些指标需要固定样本、预期答案与持续记录。

下一次遇到“改了模型设置，却像没生效”的问题，我会先追踪实际请求参数，再看模型服务本身。配置、跨语言消息和运行产物，任何一处没有跟上，都可能让修改停在半路。
