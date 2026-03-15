---
title: "给 OpenCode 接上 Playwright MCP 之后，我为什么又拆成了轻量版和调试版"
urlSlug: '20260316-01'
published: 2026-03-16
description: '记录我在 CachyOS 上给 OpenCode 接 Playwright MCP 的过程：先查官方文档，再落地 headless 配置，接着做一次真实验证，最后又把它拆成了日常用的轻量版和排查问题用的调试版。'
image: ''
tags: ["OpenCode", "Playwright", "MCP", "CachyOS", "AI Coding Agent"]
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

前两天我刚把 OpenCode 的 `skill` 这套东西接起来，结果很快又开始盯上另一块：浏览器能力。

如果你还没看前一篇，可以先读一下 [初次折腾 OpenCode Skill，为什么我先选了 Superpowers](/posts/20260313-02/)。这篇基本可以看成那篇的续篇：前一篇先把 skill 体系接起来，这一篇开始补浏览器自动化。

原因其实很简单。很多事情只靠读代码和看日志并不够，尤其是碰到前端页面、登录流程、交互错误或者一些只有跑起来才看得出来的问题时，如果 agent 能真的去打开网页、点一下、看一下页面结构，很多话就不用反复描述了。

所以我这次折腾的目标很直接：给 OpenCode 接一个 `Playwright MCP`。

## 先说结论：官方文档其实已经把路写得很直了

我一开始先看的，是 OpenCode 自己的 MCP 文档。

OpenCode 这一侧的配置思路非常直接：在 `~/.config/opencode/opencode.json` 里加一个 `mcp` 节点，声明它是本地 MCP 还是远程 MCP，然后把启动命令填进去。

也就是说，这件事在 OpenCode 这里并不神秘。它没有额外搞一套单独的 Playwright 集成方式，本质上还是标准 MCP 配置。

接着我又去看了 Playwright MCP 官方仓库。

::github{repo="microsoft/playwright-mcp"}

这个仓库 README 里甚至专门给了 OpenCode 的示例，思路也是一样的：

- 用 `npx @playwright/mcp@latest` 拉起本地 MCP 服务
- 在 OpenCode 配置里把它注册成一个本地 MCP
- 之后就能在对话里把它当工具用

所以这一步最大的收获其实不是“学会了什么黑魔法”，而是确认了一件事：这套接法是官方明确支持的，不是社区偏门玩法。

## 我第一次落地的时候，没有一上来就追求花哨

虽然 Playwright MCP 支持很多参数，但我第一次下手时的想法很保守：先跑通，再说别的。

所以我先配的是一个偏稳的 `headless` 方案。

当时我最后落下来的配置，大概是这个方向：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "playwright": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@playwright/mcp@latest",
        "--headless",
        "--output-dir",
        "/home/yangyus8/.local/share/playwright-mcp",
        "--save-trace"
      ],
      "enabled": true,
      "timeout": 15000
    }
  }
}
```

这里面我当时最在意的其实就三件事：

- 用 `npx -y`，避免第一次拉包时出现额外交互
- 强制 `--headless`，因为我主要是想让它稳定跑，不是把它当桌面浏览器
- 指定 `--output-dir` 和 `--save-trace`，这样后面真出问题时，至少有东西可以回头看

对我来说，这已经是一个很够用的第一步了。

## 真正让我安心的，不是配置写完，而是它真的跑起来了

这类东西我现在越来越不喜欢“感觉应该可以用了”这种状态。

所以配完以后，我马上做了两步验证。

第一步是看 OpenCode 有没有把这个 MCP 认出来：

```bash
opencode mcp list
```

当时实际返回里，能看到 `playwright connected`，后面还跟着完整命令行。这一步至少说明 OpenCode 没把它当成坏配置吞掉。

第二步我想要的是更硬一点的证据，于是直接跑了一次：

```bash
opencode run "use playwright to open https://example.com and tell me the page title"
```

实际输出也很直接：

```text
⚙ playwright_browser_navigate {"url":"https://example.com"}
The page title is `Example Domain`.
```

说实话，看到这一步的时候，心里就差不多有底了。因为这已经不是“配置格式看起来对”，而是它真的通过 Playwright MCP 打开了页面，并且把结果带回来了。

## 但很快我就发现，一个配置不一定适合两种场景

最开始那版跑通以后，我其实挺满意的。

但继续往下想，很快就冒出来一个现实问题：我平时用浏览器能力的场景，并不都是同一种。

有些时候我只是想让 agent：

- 打开一个页面
- 看一下标题
- 检查某个按钮在不在
- 跑一个很轻的页面验证

这种情况下，我想要的是：

- 启动别太重
- 输出别太多
- 不要每次都落一堆调试产物

但另一类情况又完全不一样。比如你真要排查一个复杂页面、登录流程、控制台报错、交互时序问题，这时候你又会希望它：

- 记录更多信息
- 把 trace 留下来
- 把 session 留下来
- 把超时放宽一点
- 最好还能带一些 devtools 相关能力

也就是说，这其实是两个不同的使用模式。

如果把它们都硬塞进同一套配置里，结果通常就是两边都不够舒服：

- 日常使用嫌太重
- 真排查问题时又嫌还不够全

## 所以我最后没有继续加参数，而是直接拆成了两套

后面我做的决定其实很简单：不再纠结“有没有一个完美配置”，而是承认这就是两种场景，然后给它们两套名字。

最后保留下来的就是：

- `playwright`：默认轻量版
- `playwright_debug`：调试版

现在我机器上的 `opencode.json` 里，大致就是这个结构：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "playwright": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@playwright/mcp@latest",
        "--headless",
        "--output-dir",
        "/home/yangyus8/.local/share/playwright-mcp",
        "--timeout-action",
        "7000",
        "--timeout-navigation",
        "45000",
        "--viewport-size",
        "1280x720"
      ],
      "enabled": true,
      "timeout": 15000
    },
    "playwright_debug": {
      "type": "local",
      "command": [
        "npx",
        "-y",
        "@playwright/mcp@latest",
        "--headless",
        "--caps",
        "devtools",
        "--console-level",
        "info",
        "--output-dir",
        "/home/yangyus8/.local/share/playwright-mcp",
        "--output-mode",
        "file",
        "--save-session",
        "--save-trace",
        "--timeout-action",
        "10000",
        "--timeout-navigation",
        "90000",
        "--viewport-size",
        "1440x900"
      ],
      "enabled": true,
      "timeout": 15000
    }
  }
}
```

我现在反而觉得，这种拆法比一味往同一个配置里堆参数更顺手。

## 轻量版和调试版，我现在是这么分工的

`playwright` 这套，我给它的定位很明确，就是默认日常版。

它保留：

- `headless`
- 固定输出目录
- 一个不算夸张的视口
- 相对保守的超时

但它不会刻意去保存 session、trace，也不会额外把一堆调试信息打开。

而 `playwright_debug` 则相反，我就是把它当作“真要排查问题时再点名使用”的版本。

它多出来的那些东西都很有针对性：

- `--caps devtools`
- `--console-level info`
- `--output-mode file`
- `--save-session`
- `--save-trace`
- 更宽的 action / navigation timeout
- 更大的桌面视口

这种分法的好处是，平时不需要频繁改配置文件。

默认就用 `playwright`。只有在我明确知道自己在做复杂排查时，才会在提示里说 `use playwright_debug`。

## 这套双配置我也顺手验证了一次

拆完以后，我又跑了一次：

```bash
opencode mcp list
```

返回结果里能同时看到：

- `playwright connected`
- `playwright_debug connected`

这一步对我来说很重要，因为它说明这不是“我在脑子里把它想成了两个模式”，而是 OpenCode 真的已经把它们识别成了两个可用的 MCP 入口。

后面在实际使用上，也就变得很自然：

日常任务直接说：

```text
use playwright to open https://example.com
```

要排查复杂问题时说：

```text
use playwright_debug to inspect this page
```

这比来回手改配置舒服太多了。

## 还有一个挺有意思的提醒：官方自己也承认，MCP 不一定永远是最优解

我在看 `microsoft/playwright-mcp` README 的时候，还有一个点让我印象挺深。

它自己其实就写得很坦白：如果你面对的是典型的 coding agent 场景，有时候 `Playwright CLI + skills` 可能反而比 MCP 更省上下文，也更适合高频开发工作流。

这一点我觉得挺诚实的。

因为 MCP 的确很强，尤其适合那种需要持续浏览器状态、持续交互、持续推理页面结构的场景。但它也确实会把更多工具定义和页面信息带进上下文里。

所以我现在的理解是：

- 想先把浏览器自动化能力接进 OpenCode，MCP 是很直接的路
- 真要走到高频、重度、长期使用阶段，要不要换成 CLI + skills，那是下一阶段再考虑的事

而我后面确实又去把 CLI 这条路补上了，过程单独写在 [在 CachyOS 上给 OpenCode 接 Playwright CLI：为什么我又手动搬了一次 skill](/posts/20260316-02/) 里。

至少对我现在这个阶段来说，先把 MCP 稳稳接起来，已经很值了。

## 回头看，这次折腾最有用的不是某个参数，而是我终于把使用场景拆开了

如果只看最后那份配置文件，好像这次折腾无非就是多写了几行参数。

但对我自己来说，真正有价值的反而是另一个转变：我不再试图用一套“看起来最全”的配置解决所有事情了。

浏览器自动化这件事，本来就有两种完全不同的需求：

- 日常轻用
- 出问题时深挖

把这两种场景承认下来，然后分别给它们一个入口，比追求一个“大而全”的万能配置更实用。

所以如果现在让我给同样在折腾 OpenCode MCP 的人一句建议，我大概会说：

先配一版能稳定工作的 `headless` 基础版，先验证它真的能跑。等你真的开始频繁用它，再考虑要不要拆出一版专门的调试配置。

对我这台 CachyOS 机器来说，这一步就刚好停在一个很舒服的位置：

- 平时有轻量版可用
- 真要查问题时有调试版可切
- 而且两套都已经被 OpenCode 实际识别和跑通了

这比我一开始预想的“先装上再说”，其实已经往前走了不少。
