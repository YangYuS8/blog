---
title: "为什么 opencode 明明装好了，OpenClaw 却还是拉不起来：一次 ACP backend 排障记录"
urlSlug: '20260325-01'
published: 2026-03-25
description: '记录一次 OpenClaw ACP 排障：为什么 opencode 命令本身可用，但通过 OpenClaw 的 ACP runtime 调用时仍然报错；最后如何定位到 acpx 插件和 acp 顶层配置缺失的问题。'
image: ''
tags: ['OpenClaw', 'ACP', 'opencode', 'Linux', '故障排查']
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

前面折腾 OpenClaw 的时候，我一直以为 `opencode` 这条链路已经算通了。

因为从最表面的检查来看，它确实没有问题：

- 命令存在
- PATH 已经补进了 OpenClaw 的运行环境
- `coding-agent` 相关检查也不再是 `blocked`

但真到要把它当作 **ACP runtime** 去拉起时，OpenClaw 给出的反馈却不是“正在运行”，而是另一种更让人烦躁的提示：

> `ACP runtime backend is not configured`

这类报错的麻烦之处在于，它不是那种“一眼就知道缺哪个二进制”的问题。

它说明的是：

- `opencode` 命令本身也许没坏
- 但 OpenClaw 这一层并不知道该怎么把它接成一个可用的 ACP 运行时

这篇文章就记录一下这次排障过程：为什么 `opencode` 明明装好了，却还是拉不起来；以及最后到底修了哪些东西，才把它真的变成可用状态。

## 先确认：问题不在 `opencode` 命令本身

排这种问题时，第一步当然还是先看最基础的事实。

在这台机器上，我确认到的状态是：

```bash
command -v opencode
opencode --version
```

结果是正常的：

- `opencode` 路径存在
- 版本也能输出

也就是说，问题不在“命令没装”或者“PATH 不对”这一层。

这一步其实很重要，因为如果一开始连这层都没过，那后面就没必要去怀疑 OpenClaw 的 ACP 机制。

## 为什么我没有停在“命令能跑就算好了”

因为 OpenClaw 里有两层东西很容易被混为一谈：

### 第一层：命令能不能执行

比如：

- `opencode` 在不在 PATH
- 手动敲命令有没有版本输出

### 第二层：OpenClaw 能不能把它当作 ACP runtime 调度起来

这又是另一件事。

`sessions_spawn(runtime="acp", agentId="opencode")` 走的不是普通 shell 命令调用，而是：

- ACP runtime backend
- agent/harness 映射
- Gateway / runtime 配置
- 后端插件加载

如果这一层没配，哪怕 `opencode` 本体再正常，OpenClaw 也还是会报：

```text
ACP runtime backend is not configured
```

这也是这次问题的核心。

## 真正的排查思路：去看 OpenClaw 的 ACP 配置，而不是继续盯着 `opencode`

确认 `opencode` 本体没问题之后，我开始往 OpenClaw 配置本身看。

先看当前的 `~/.openclaw/openclaw.json`，重点关注：

- 有没有 `acp` 顶层配置
- 有没有和 ACP runtime 相关的 agent 配置
- 有没有启用 ACP backend plugin

结果很快就看出问题了。

### 1. `openclaw.json` 里完全没有 `acp` 顶层配置

也就是说，当时配置里根本没有类似这些东西：

```json
{
  "acp": {
    "enabled": true,
    "backend": "acpx",
    "defaultAgent": "opencode"
  }
}
```

如果这层没写，OpenClaw 就根本不知道：

- ACP 是否启用
- 默认 backend 是谁
- 默认 agent 应该映射到哪个 harness

### 2. `acpx` 插件虽然存在，但它是 disabled

我又去看了插件状态：

```bash
openclaw plugins list
```

结果里能看到一项很关键的条目：

- `ACPX Runtime | acpx | disabled`

也就是说：

- OpenClaw 这版其实**自带** ACPX Runtime 插件
- 但它当时并没有启用

这一步基本就把问题锁死了。

因为文档里已经说得很明白：

> `ACP runtime backend is not configured`
> 通常意味着 backend plugin missing or disabled

换句话说，真正的根因是：

- `opencode` 命令本身没问题
- 但 **OpenClaw 的 ACP backend 这层根本没接好**

## 再看文档，确认这条路该怎么配

接下来我没继续拍脑袋改，而是去翻了 OpenClaw 本地文档，重点看 ACP 相关说明。

从文档里能确认几件很关键的事情：

### 1. ACP 需要顶层 `acp` 配置

文档示例里有一段非常关键的 baseline 配置，大意就是：

```json5
{
  acp: {
    enabled: true,
    dispatch: { enabled: true },
    backend: "acpx",
    defaultAgent: "codex",
    allowedAgents: ["pi", "claude", "codex", "opencode", "gemini", "kimi"]
  }
}
```

这说明：

- `acp.enabled=true` 是必须的
- backend 应该明确指向 `acpx`
- agent allowlist 也要覆盖到要使用的 harness

### 2. `opencode` 确实是 acpx 支持的 harness alias

文档里还专门列了当前 acpx 内建支持的 harness alias：

- `pi`
- `claude`
- `codex`
- `opencode`
- `gemini`
- `kimi`

这一步很关键，因为它说明：

> 我不是在硬把一个不支持的命令往 ACP 里塞。

`opencode` 在这版文档语义里，确实是 ACPX backend 应该支持的 agent id。

### 3. `acpx` 插件本来就是官方推荐 backend

文档里关于 plugin setup 也写得很直接：

- `acpx` 是 ACP backend plugin
- 要安装并启用
- 启用后 OpenClaw 才能把外部 harness 当作 ACP runtime 用

到了这里，问题基本已经从“猜测”变成“按图施工”。

## 实际修复：补两层配置

最后我做的修复主要就是两层。

### 第一层：补顶层 `acp` 配置

我在 `openclaw.json` 里加上了类似这样的配置：

```json
"acp": {
  "enabled": true,
  "dispatch": {
    "enabled": true
  },
  "backend": "acpx",
  "defaultAgent": "opencode",
  "allowedAgents": [
    "pi",
    "claude",
    "codex",
    "opencode",
    "gemini",
    "kimi"
  ],
  "maxConcurrentSessions": 8,
  "stream": {
    "coalesceIdleMs": 300,
    "maxChunkChars": 1200
  },
  "runtime": {
    "ttlMinutes": 120
  }
}
```

这层的作用就是：

- 打开 ACP 总开关
- 指定 backend 为 `acpx`
- 把 `opencode` 设成默认 agent
- 明确 allowlist，避免被策略层挡掉

### 第二层：启用 `acpx` 插件

然后在插件配置里把 `acpx` 打开：

```json
"plugins": {
  "allow": [
    "telegram",
    "openclaw-weixin",
    "acpx"
  ],
  "entries": {
    "acpx": {
      "enabled": true,
      "config": {
        "permissionMode": "approve-all",
        "nonInteractivePermissions": "deny"
      }
    }
  }
}
```

这里我还顺手加了非交互权限策略。

因为 ACP session 是没有 TTY 的，如果后端 runtime 遇到权限提示，又没有明确策略，就很容易卡在“等待交互确认但根本没人能确认”的尴尬状态。

## 中途最烦的不是 ACP 本身，而是 Gateway 重启路径

配置补完之后，本来应该顺手重启 gateway 然后验证就结束了。

但实际过程中还有一个让人非常不爽的小坑：

```text
gateway.auth.token SecretRef is configured but unavailable in this command path
```

简单说就是：

- gateway 的 token 走的是环境变量 / SecretRef
- 我在某些命令路径下重启 gateway 时，OpenClaw CLI 自己会先做 token drift 校验
- 结果它在当前执行路径里拿不到对应上下文
- 然后就把自己拦下来了

这就导致一种很绕的情况：

- ACP 配置其实已经改好了
- 但 gateway 重启这一步，却被另一层安全校验挡住

最后我是让 gateway 通过正确环境路径吃到配置之后，再继续验证的。

这类问题很典型，也说明了一个很现实的经验：

> OpenClaw 这种系统，很多时候真正耗时间的不是“功能配置本身”，而是“配置写进去之后，服务到底有没有在正确环境里重新加载”。

## 最终验证：关键不是 CLI，关键是 ACPX Runtime 真的 loaded 了

最后最重要的验证不是“我觉得改对了”，而是：

```bash
openclaw plugins list
```

从这里看到：

- `ACPX Runtime | acpx | loaded`

这说明至少最核心的一步已经过了：

> **OpenClaw 现在已经真正把 ACP backend 加载起来了。**

而不是停留在配置文件层面的“看起来写上了”。

更进一步，我实际调用：

```json
sessions_spawn(runtime="acp", agentId="opencode")
```

也已经不再报：

```text
ACP runtime backend is not configured
```

而是能被接受，并生成真正的 ACP 子会话。

这一步才算把整个问题彻底坐实地修好。

## 这次排障里，最值得记住的几件事

如果要把这次经历浓缩成几个最有价值的经验，我会记这几条。

### 1. 命令存在，不等于 runtime 就已经接好了

这是最容易让人误判的地方。

- `opencode` 在 PATH 里
- `opencode --version` 能跑

只能说明：

> **命令本体可用**

但这和：

> **OpenClaw 能不能把它当作 ACP runtime 调度**

是两回事。

### 2. 看到 `ACP runtime backend is not configured`，优先去查 plugin 和 ACP 顶层配置

这类报错不要继续死盯 `opencode` 本身。

更应该先查：

- `acp.enabled`
- `acp.backend`
- `acp.allowedAgents`
- `plugins.entries.acpx.enabled`
- `openclaw plugins list`

尤其是最后这个命令，信息量很大。

### 3. `disabled` 和 `loaded` 差别非常大

在 OpenClaw 里，配置写上去不等于运行态已经生效。

如果插件状态还是：

- `disabled`

那就别急着测功能。先把它变成：

- `loaded`

再说后面的事情。

### 4. Gateway 环境路径问题，很多时候比业务配置本身更烦

这次真正让我多绕了几圈的，反而不是 ACP 配置逻辑，而是：

- gateway token 的环境路径
- CLI 自带的校验
- 服务重启时到底吃到了什么环境

这种问题很像“系统胶水层”的典型故障：

- 业务逻辑没错
- 但 glue code / runtime environment 不对
- 最后还是跑不起来

## 最后的结论

回到最初那个问题：

> **为什么 `opencode` 明明装好了，OpenClaw 却还是拉不起来？**

答案其实很简单：

> **因为装好的只是命令，不是 ACP runtime。**

真正缺的是：

- ACP 顶层配置
- `acpx` backend 插件启用
- `opencode` agent 允许与映射
- 正确的 gateway 重新加载路径

把这些都补齐之后，`opencode` 才不再只是“系统里有这个命令”，而是真正成为：

> **能被 OpenClaw 作为 ACP runtime 正常调度的外部 harness。**

这次排障最核心的一点，不是修了某一条 JSON，而是把“命令存在”和“运行时接线完成”这两件事彻底区分开了。
