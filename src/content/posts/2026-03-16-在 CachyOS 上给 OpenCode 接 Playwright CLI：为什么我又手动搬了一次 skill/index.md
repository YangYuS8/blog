---
title: "在 CachyOS 上给 OpenCode 接 Playwright CLI：为什么我又手动搬了一次 skill"
urlSlug: '20260316-02'
published: 2026-03-16
description: '记录我在 CachyOS 上用 pnpm 给 OpenCode 接 Playwright CLI 的过程：官方为什么更推荐 CLI + skills、为什么全局安装之后 skill 却先落到了工作区，以及我最后为什么又把它手动搬到真正的全局目录。'
image: ''
tags: ["OpenCode", "Playwright CLI", "CachyOS", "pnpm", "Agent Skills"]
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

给 OpenCode 配完 `Playwright MCP` 之后，我本来以为浏览器这块差不多就先告一段落了。

如果你前面的文章还没看，这篇其实排在另外两篇后面会更顺：先是 [初次折腾 OpenCode Skill，为什么我先选了 Superpowers](/posts/20260313-02/)，再是 [给 OpenCode 接上 Playwright MCP 之后，我为什么又拆成了轻量版和调试版](/posts/20260316-01/)。这篇更像是那两篇之后的一次补充折腾。

结果没过多久，我又开始去看另一条路：`playwright-cli`。

原因倒不是 MCP 不好用。相反，我前面已经把它跑通了，`opencode mcp list` 能认出来，`opencode run` 也能真的打开 `example.com`。但我后来看官方文档时，注意到一个挺关键的提醒：对于 coding agent 这类场景，很多时候 `CLI + skills` 反而比 MCP 更合适。

这个说法我一下就记住了。

## 为什么我会继续去看 `playwright-cli`

我先去看了官方仓库：

::github{repo="microsoft/playwright-cli"}

这个项目的定位写得很直白，就是“Playwright CLI with SKILLS”。

它对 MCP 和 CLI 的区分也讲得很明确：

- MCP 更适合需要持续浏览器状态、持续页面推理的 agent 循环
- CLI + skills 更适合 coding agent，因为它更省上下文

这个判断对我来说挺有说服力。

毕竟 OpenCode 这种工具平时干的事情，不只是盯着浏览器看页面，它还要读代码、跑命令、改文件、分析项目结构。上下文窗口本来就很宝贵。如果浏览器自动化这部分能用更轻一点的方式接进去，确实值得试。

所以我这次想做的事情就变成了：在保留 MCP 的前提下，再给这台机器补上一条 `playwright-cli` 的路。

## 这次我一开始就决定用 `pnpm`

官方 README 里的安装示例写的是：

```bash
npm install -g @playwright/cli@latest
playwright-cli --help
playwright-cli install --skills
```

但我这台机器平时包管理已经是 `pnpm` 为主了，所以这次我一开始就没打算回退到 `npm -g`。

最后我实际跑的是：

```bash
pnpm add -g @playwright/cli@latest
```

装完之后，先确认命令能不能起来：

```bash
playwright-cli --version
playwright-cli --help
```

当时版本号是：

```text
1.59.0-alpha-1771104257000
```

接着 `--help` 也正常吐出了完整命令列表。到这里为止，一切看起来都挺顺。

## 真正有意思的地方，是后面的 `install --skills`

按 README 的写法，下一步很自然就是：

```bash
playwright-cli install --skills
```

我一开始对这步的预期其实很简单：既然 CLI 是全局装的，那 skills 最好也顺手装到一个全局可用的位置。

结果实际输出却不是我脑子里想的那种“全局初始化”，而是：

```text
✅ Workspace initialized at `/home/yangyus8/Code/blog`.
✅ Skills installed to `.claude/skills/playwright-cli`.
✅ Found chrome, will use it as the default browser.
```

看到这里的时候，我第一反应其实是：嗯？怎么又回到工作区了？

因为这意味着，虽然 `playwright-cli` 这个二进制本身确实是全局安装的，但它的 skills 安装逻辑明显更偏 workspace 导向。它不是直接往 `~/.config/opencode/skills/` 里塞，而是优先在当前目录下初始化一套 `.claude/skills/playwright-cli`。

## 这件事不是错，但我还是觉得不够干净

说实话，这样装出来的结果并不是完全不能用。

OpenCode 本身就兼容 `.claude/skills/`，所以从“能不能识别”这个角度说，这套东西其实已经够用了。

但我还是觉得它有点别扭，原因主要有两个。

第一，它和我前面的目标不完全一致。

我这次想做的是“给这台机器补一套全局可复用的 Playwright CLI 能力”，不是“只给当前 blog 仓库放一套 skill”。如果 skill 继续留在 `blog/.claude/skills/`，那它的全局可用性其实是建立在“这个仓库一直在这个路径上”这个前提上的。

第二，它会让结构看起来不够清楚。

我现在这台机器上，OpenCode 的主配置已经基本都在 `~/.config/opencode/` 下面了：

- `plugins/`
- `skills/`
- `opencode.json`
- `superpowers/`

如果 `playwright-cli` 的 skill 还挂在某个具体仓库里，整体上就有一种“功能是全局的，来源却是局部的”的感觉。

能用归能用，但不够利索。

## 所以我最后还是手动搬了一次

后面我做的事情其实很朴素：既然它默认装到了当前工作区，那我就把这套 skill 明确搬到全局目录里。

当时的路径关系大概是这样：

- 工作区生成的 skill：`/home/yangyus8/Code/blog/.claude/skills/playwright-cli`
- OpenCode 全局 skills：`/home/yangyus8/.config/opencode/skills/`

我最开始先做了一步兼容处理：把工作区那份 skill 链接到全局目录。这样可以先确保 OpenCode 在全局位置能看到它。

但后面我还是决定更彻底一点，直接把那套内容复制到真正的全局目录里，让它不再依赖 `blog` 仓库路径。

最后稳定下来的位置就是：

- `/home/yangyus8/.config/opencode/skills/playwright-cli`

而且这个目录现在已经不是 symlink，而是一个真实目录，里面有：

- `SKILL.md`
- `references/`

这一步做完以后，我才觉得这套东西算是真的“装干净了”。

## 这套 skill 本身长什么样，我也顺手看了一眼

我后来读了一下全局目录里的 `SKILL.md`，内容其实挺实在的。

它的 frontmatter 很简单：

- `name: playwright-cli`
- `description:` 说明它适合网页交互、表单填写、截图、数据提取这类任务
- `allowed-tools: Bash(playwright-cli:*)`

这一点我挺喜欢，因为它的意图很清楚：不是把浏览器控制能力塞成一堆庞大的 MCP 工具 schema，而是明确告诉 agent——你该通过 `playwright-cli` 这组命令去做这件事。

这和它官方强调的“对 coding agent 更省上下文”其实是对得上的。

## 我是怎么验证它真的装好的

这种安装类动作我现在已经养成习惯了，不太相信“看起来好像差不多”。

所以这次我也做了几层验证。

第一层，是看命令本身是不是能跑：

```bash
playwright-cli --help
```

这一步确认的是：全局二进制已经在 PATH 上，而且命令本身可用。

第二层，是做一个最小冒烟测试：

```bash
playwright-cli open https://example.com
playwright-cli close
```

实际输出里能看到：

```text
Page URL: https://example.com/
Page Title: Example Domain
```

这比单纯看 `--help` 更有说服力，因为它说明浏览器真的被拉起来了，页面也真的被打开了。

第三层，是确认 skill 的全局目录状态：

```bash
ls -ld ~/.config/opencode/skills/playwright-cli
```

我最终确认到的是：它已经是普通目录，不再是指向 `blog` 仓库的符号链接。

第四层，是顺手做了个回归检查：

```bash
opencode mcp list
```

这样做的原因也很简单——我不想为了接一套 CLI skills，把前面已经配好的 `playwright` / `playwright_debug` MCP 给弄坏了。

最后这一步也正常，两套 MCP 还都在，说明这两条路是可以并存的。

## 回头看，这次最值得记一笔的不是安装命令，而是它的默认行为

如果只看命令，这次其实没什么复杂的：

```bash
pnpm add -g @playwright/cli@latest
playwright-cli install --skills
```

真正让我觉得“值得写下来”的，反而是它的默认行为。

我原本下意识以为：全局安装 CLI，skills 也应该顺手全局化。

但 Playwright CLI 实际给出的选择是：先初始化当前 workspace，再把 skills 落到 `.claude/skills/` 里。

从它自己的视角看，这个行为其实完全说得通，因为很多 coding agent 的典型工作方式本来就是围绕当前仓库展开的。

但从我自己的使用习惯看，我更想把这套东西收束到 OpenCode 的全局配置目录里。所以最后才有了那一步手动搬迁。

## 现在这台机器上的状态，我自己还挺满意

现在回头看，我这台 CachyOS 机器上的浏览器自动化相关能力，大概已经形成了比较清楚的两条线：

- 一条是 `Playwright MCP`
- 一条是 `playwright-cli + skills`

而且两边都不是半吊子状态：

- MCP 这边已经拆成了 `playwright` 和 `playwright_debug`
- CLI 这边已经是 `pnpm` 全局安装，并且 skill 真正落到了 `~/.config/opencode/skills/playwright-cli`

这种状态比我最开始预想的“先装上再说”要清楚很多。

至少现在如果我以后再开别的仓库，不需要想着“这个 skill 当初是不是装在 blog 项目里了”，也不用担心某个仓库路径一变，全局能力就跟着悬空。

## 如果下次还有人也想这么配，我大概会先提醒这一句

如果你也打算像我一样，用 `pnpm` 全局安装 `playwright-cli` 给 OpenCode 配浏览器能力，我觉得最值得先知道的一件事不是安装命令，而是这个：

`playwright-cli install --skills` 默认更像是“初始化当前工作区”，而不是“无脑装进全局 OpenCode 目录”。

知道这一点以后，后面的预期就会清楚很多。

你可以接受它直接留在工作区；也可以像我一样，跑通之后再手动把 skill 收拢到真正的全局目录里。

对我来说，后者更符合我现在这台机器的整体配置方式。

所以这篇文章写到最后，真正想记下来的也就是这一句：`Playwright CLI` 本身装起来不难，难得其实是你要先想清楚，自己想要的是“工作区技能”，还是“全局技能”。

我这次最后选的是后者。
