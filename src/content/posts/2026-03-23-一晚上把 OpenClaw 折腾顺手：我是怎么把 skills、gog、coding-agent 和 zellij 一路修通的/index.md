---
title: "一晚上把 OpenClaw 折腾顺手：我是怎么把 skills、gog、coding-agent 和 zellij 一路修通的"
urlSlug: '20260323-01'
published: 2026-03-23
description: '记录我一晚上把 OpenClaw 从“能跑但不顺手”折腾到“skills 基本就绪”的过程：清理重复 skill、切回官方内置版本、修通 gog、把 coding-agent 从 blocked 变成 ready，最后再换掉 tmux 改用 zellij。'
image: ''
tags: ['OpenClaw', 'Linux', 'DevOps', 'skills', 'gog', 'coding-agent', 'zellij']
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

这篇文章其实是昨晚一次非常典型的“本来只是想试一下，结果一路越修越深”的折腾记录。

最开始我只是想确认 OpenClaw 现在到底能做什么，顺手看看它的联网搜索、ClawHub 和 skills 状态。结果越看越不对劲：有些 skill 明明装着，但其实不能用；有些和官方内置版本重复；还有些在命令行里看着正常，面板里却还是 `blocked`。

最后这一晚上，我把这些问题基本都收拾了一遍，顺手还把 `gog`、`coding-agent`、`zellij` 这些平时真的会用到的能力打通了。

回头看，这次最值得记下来的不是某一条命令，而是整条排障思路：**先分清“安装了”和“真的可用”不是一回事，再把环境、PATH、密钥、服务上下文一层一层理顺。**

## 先看清楚：哪些 skill 是“装了但其实还不能用”

我最开始做的事情其实很朴素：先列出当前装了哪些 skills，然后逐个检查它们是不是真的能工作。

当时本地通过 ClawHub 装着这些：

- `self-improving-agent`
- `gog`
- `liang-tavily-search`
- `find-skills-skill`
- `github`
- `notion`
- `summarize`
- `skill-vetter`

第一轮检查只看目录和 `SKILL.md`，它们全都“看起来没问题”。但真正往下查依赖之后，情况马上就变了。

例如：

- `gog` 当时缺命令本体
- `github` 缺 `gh`
- `notion` 缺 API key
- `summarize` 缺 CLI
- `liang-tavily-search` 缺 `TAVILY_API_KEY`

这一步给我的提醒非常直接：

> 对 skill 来说，“目录存在”和“现在真的可用”是两码事。

如果只看 `clawhub list`，你只能知道“它被安装过”；但真正决定它能不能用的，是二进制、环境变量、授权状态和服务运行上下文。

## 把重复安装清掉，只留官方内置版本

继续往下看时，我又发现了第二个问题：有一些 skill 明明 OpenClaw 已经自带了官方版本，我工作区里却又额外装了一份。

重复项主要是这四个：

- `gog`
- `github`
- `notion`
- `summarize`

这种状态其实挺别扭，因为你很难第一时间分清：当前 agent 读到的到底是工作区版本，还是官方 bundled 版本。

所以我后面干脆做了个取舍：

- 保留官方内置版本
- 用 `clawhub uninstall` 卸载工作区重复副本

这样做之后，技能来源一下就清楚了：常用能力尽量走官方 bundled，工作区只保留真正额外装的第三方 skill。

这一步做完以后，整个 skill 体系至少先从“重复叠加”变成了“来源清楚”。

## 启用官方内置 skill 时，真正关键的是 eligibility

接下来我要做的事情，是把几项常用官方 skill 真正启起来：

- `github`
- `gog`
- `notion`
- `summarize`
- `gemini`

后面又补了：

- `blogwatcher`
- `coding-agent`
- `gifgrep`
- `video-frames`
- `zellij`

这里最容易踩的坑，是以为“配置里 enabled: true”就完事了。

其实 OpenClaw 这套机制更像是两层判断：

1. 你有没有在配置里允许它出现
2. 当前主机环境有没有满足它的 requirements

后者包括：

- 二进制在不在 PATH
- 环境变量在不在
- 授权状态是不是可用
- 当前操作系统是否匹配

所以后面我每启一批 skill，都会顺手跑：

```bash
openclaw skills info <name>
openclaw skills list --eligible
```

这一步非常值，因为它能直接把“配置问题”和“运行条件问题”分开。

## `gog`：真正的难点不是装，而是服务器环境下的 token 存储

这一晚最折腾人的一条链路，其实是 `gog`。

一开始我的目标只是想让 OpenClaw 能读 Google Calendar、传文件到 Google Drive，看起来也不复杂：

- 把 `gogcli` 装上
- 做一次授权
- 然后直接用

结果真正开始之后，问题一层接一层。

### 第一步：Linux 上不用 brew，从源码把 `gogcli` 编出来

因为这台机器不想装 Homebrew，所以我最后走的是源码构建。

大致流程就是：

```bash
git clone https://github.com/steipete/gogcli.git
cd gogcli
make
install -Dm755 ./bin/gog ~/.local/bin/gog
```

这一步本身不算难，Go 和 `make` 都在，编译完之后 `gog --help` 也正常起来了。

所以安装阶段的问题不大。

### 第二步：真正的问题出在 keyring

装完之后，我第一次试着查 Google Calendar，结果不是 API 报错，而是：

```text
Cannot get secret of a locked object
```

这说明旧 token 是存在的，但它被存在了系统 keyring 里，而当前服务器环境取不出来。

这时候我才意识到：

> 在纯 Linux 服务器 / 非图形会话下，依赖桌面 keyring 这件事并不稳。

于是我后面把 `gog` 的 keyring backend 从默认的 `auto`，改成了 `file`。

```bash
gog auth keyring file
```

这个选择的核心逻辑其实很简单：

- 服务器环境要的是可预测、可非交互调用
- 不是“桌面体验好不好”

### 第三步：切到 file backend 之后，还得重新登录一次

backend 改完，不等于旧 token 自动跟着迁过去。

因为旧 token 本来就在锁着的 keyring 里，既然拿不出来，就不可能无损迁移。所以后面还是得重新登录一次 `gog`，把 refresh token 存到新的 file backend 里。

而且 file backend 还多了一个要求：

```text
set GOG_KEYRING_PASSWORD
```

也就是说，非交互环境下要想让 `gog` 能自由调用，就得给它提供一个 keyring password。

最后这条链路的稳定方案就变成了：

- `gog` 使用 file backend
- 设置 `GOG_KEYRING_PASSWORD`
- 在 OpenClaw / shell 环境里把它导入

这一套通了之后，后面我已经能用它做两件实际事情：

1. 查 Google Calendar
2. 把文件直接上传到 Google Drive

对我来说，这时候 `gog` 才算真的从“装好了”变成“可用了”。

## `coding-agent`：命令行 ready，不代表面板就 ready

这一晚第二个很典型的坑，是 `coding-agent`。

一开始它一直是 `blocked`，原因也很明确：要求的二进制一个都没认到。

后来我知道机器上其实已经装了 `opencode`，只是 OpenClaw 还是不认。这种情况最容易让人误判成：

- skill 有 bug
- OpenClaw 没刷新
- 面板显示错了

但继续往下查，我发现问题根本不在 skill 本身，而在 **运行上下文**。

### 真正的症结：`.bashrc` 只在 interactive shell 里加了 PATH

我后来去看了 `~/.bashrc`，发现里面确实有：

```bash
export PATH=/home/geneden/.opencode/bin:$PATH
```

但问题是，这行写在了只对 interactive shell 生效的逻辑后面。

前面有这一段：

```bash
case $- in
    *i*) ;;
      *) return;;
esac
```

这就意味着：

- 你自己开交互式 shell 时，`opencode` 在 PATH 里
- OpenClaw 的非交互检查命令，不会走到后面的 PATH 导出

所以会出现一个很迷惑的现象：

- 你在自己终端里敲，觉得 `opencode` 明明在
- OpenClaw 面板里看，`coding-agent` 还是 blocked

### 先修 shell，不够；真正要修的是 gateway service 的 PATH

我最开始也差点被这个问题带偏，以为只要把 PATH 加进环境文件就结束了。

后来继续查 `openclaw gateway status` 和 systemd service 文件，才发现真正重要的是：

> 面板看的不是你当前交互 shell 的 PATH，而是 gateway service 进程自己的 PATH。

我最后看到的 service 文件里，PATH 本来是：

- `~/.local/share/pnpm`
- `~/.local/bin`
- 以及一串常规目录

但就是没有：

- `/home/geneden/.opencode/bin`

后面真正把问题彻底修掉的动作，是把它补进 `openclaw-gateway.service` 的 PATH 里，然后重载 / 重启服务。

修完后再看：

```bash
openclaw skills info coding-agent
```

它终于从 `Missing requirements` 变成了：

```text
✓ Ready
```

这次踩坑给我的最大提醒是：

> 对 systemd 托管的服务来说，你在终端里“能跑”的命令，不等于服务进程也“能看见”。

## `tmux` 不是一定要死磕，换成更适合自己的 `zellij` 就行

原本我还打算顺手把 `tmux` 也修好，因为 OpenClaw 里有对应 skill。

但后面想了想，这其实不值得死磕。

原因很简单：

- `tmux` skill 虽然有
- 但我平时更想用的是 `zellij`

既然如此，没必要为了“让一个 skill 亮绿灯”去用一个自己并不偏爱的工具。所以后面我就直接换策略：

1. 停用 `tmux`
2. 去 ClawHub 搜 `zellij` skill
3. 直接安装 `zellij`

结果还挺顺：

```bash
clawhub search zellij
clawhub install zellij
```

装完之后，`zellij` 这条很快就 ready 了。

这一步其实也挺能说明一个问题：

> 配环境不是做题，不是“系统给了什么就必须用什么”，而是应该围绕自己的真实工作流来。

如果你平时就是更想用 `zellij`，那让它进入你的 OpenClaw 工作流，本来就比把 `tmux` 勉强修到能用更合理。

## 中间还踩了一个小坑：`openclaw doctor --repair` 不是所有场景都能一键救命

这一晚我也试过让 OpenClaw 自己修自己：

```bash
openclaw doctor --repair
```

思路当然没问题，但实际执行时它被 SecretRef 卡住了，因为当前命令路径下拿不到某些 `env` secret。

这件事让我对 `doctor --repair` 的预期更现实了一点：

- 它很适合做常规体检和修一些标准化问题
- 但一旦牵涉到服务上下文、SecretRef、systemd 环境这种东西，还是得自己下去看 service 文件和实际 PATH

换句话说，它很好用，但不是万能按钮。

## 回头看，这一晚上真正被理顺的是 4 件事

如果只看结果，这一晚最后我真正得到的东西其实很明确：

### 1. skill 体系干净了

- 清掉了和官方内置重复的 skill
- 常用 skill 都回到了更清晰的来源结构

### 2. `gog` 真的能用了

- 能查 Google Calendar
- 能传文件到 Google Drive
- 不再依赖不稳定的桌面 keyring

### 3. `coding-agent` 不再只是“命令行里看着像正常”

- 而是 gateway service 也真的认到了 `opencode`
- 面板状态和实际环境终于一致了

### 4. 终端工作流也更符合自己的习惯了

- 不再死磕 `tmux`
- 改成了更想用的 `zellij`

这四件事加在一起，OpenClaw 才从“能跑”变成了“顺手”。

## 最后记三条我觉得最有价值的经验

### 第一，先分清“已安装”和“可用”

`clawhub list`、skill 目录、`SKILL.md` 这些都只能证明它“在”，不能证明它“现在真的能工作”。

真正决定可用性的，是：

- 二进制
- API key
- 授权状态
- 服务运行上下文

### 第二，服务问题优先看 systemd 环境，而不是只看当前 shell

如果一个命令你在终端里明明能跑，但 OpenClaw 面板里还是 blocked，那优先怀疑：

- gateway service 的 PATH
- EnvironmentFile
- systemd 实际注入了什么环境变量

这比盯着 `.bashrc` 自己脑补要有效得多。

### 第三，服务器场景下，越“桌面味”的密钥方案越容易不稳定

像 `gog` 这种需要长期非交互调用的工具，如果把关键 token 建在桌面 keyring 的体验假设上，放到服务器里就很容易出问题。

在这种场景下，能清楚控制的 file backend 和环境变量，反而更靠谱。

---

如果你现在也在折腾 OpenClaw，尤其是已经开始用 skills、gog、coding-agent 这几条线了，那我觉得最值得先做的不是拼命加新功能，而是先把这几件事理顺：

- skill 来源别重复
- eligibility 别只看 enabled
- PATH 别只修 shell，不修 service
- 能走稳定后端的授权，就尽量别赌桌面 keyring

把这些打通之后，后面的体验会顺很多。
