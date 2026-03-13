---
title: "初次折腾 OpenCode Skill，为什么我先选了 Superpowers"
urlSlug: '20260313-02'
published: 2026-03-13
description: '记录我第一次认真了解 OpenCode skill 生态的过程：vercel-labs/skills 到底是干什么的、在 CachyOS 上怎么把 skill 接进 OpenCode，以及我为什么最后没有一口气装很多，而是先从 superpowers 开始。'
image: ''
tags: ["OpenCode", "Agent Skills", "CachyOS", "Superpowers"]
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

这两天我第一次认真去看 OpenCode 里的 `skill` 到底是怎么回事。

之前我对这东西一直是模模糊糊的印象，知道它大概是“给 agent 补一层额外能力”，但具体怎么装、和普通提示词有什么区别、哪些仓库才是值得装的，我其实都没真正理清楚。

这次刚好借着在 CachyOS 上折腾 OpenCode，我把几个相关仓库和文档都顺手看了一遍。最后的结论倒没有想象中复杂：先别急着把一堆 skill 往里塞，先搞清楚谁是安装器，谁是技能内容，再选一个最适合日常使用的起点就行。

## 我最先看的是 `vercel-labs/skills`

::github{repo="vercel-labs/skills"}

最开始看到这个仓库名字的时候，我还以为它就是一个“大型 skill 合集”。

但看完 README 之后我才反应过来，它更像是 skill 生态里的包管理工具，而不是技能内容本身。

它做的事情主要是这些：

- 从 GitHub 仓库、本地目录、git URL 里找到 `SKILL.md`
- 把 skill 安装到不同 agent 约定好的目录
- 提供 `add`、`list`、`check`、`update`、`remove` 这类命令
- 让同一个 skill 仓库可以被多个 agent 复用

也就是说，`vercel-labs/skills` 更像是“技能安装器”，真正的 skill 内容反而通常在别的仓库里。

比如它 README 里最常见的例子就是：

```bash
npx skills add vercel-labs/agent-skills
```

所以如果只看名字，很容易把它理解偏。它不是“技能包本体”，而是“把技能包装进 agent”的那一层。

## 接着我去看了 OpenCode 自己的 skills 文档

我后来又专门看了 OpenCode 官方文档里关于 skills 的部分，主要是想确认一件事：OpenCode 自己到底认哪些目录。

它会在这些位置查找 `SKILL.md`：

- `~/.config/opencode/skills/<name>/SKILL.md`
- `.opencode/skills/<name>/SKILL.md`
- `.agents/skills/<name>/SKILL.md`
- `.claude/skills/<name>/SKILL.md`

这一点其实很重要，因为它直接决定了我后面应该怎么装。

我这台机器平时不是只开一个仓库，更多时候是在不同项目之间来回切。所以比起一开始就做 project-local 的 skill，我更倾向于先把能力装到全局目录里，让 OpenCode 先形成一个稳定的默认层。

换句话说，我更适合的是这种路线：

- 先装到 `~/.config/opencode/skills/`
- 优先全局使用
- 能 symlink 就用 symlink

Linux 上这套很自然，后面更新也轻松。

## 我本机环境其实已经够了

真正决定动手之前，我顺手确认了一下环境。

当时的状态大概是这样：

- `opencode 1.2.25`
- `node 24.14.0`
- `npm 11.9.0`
- `pnpm 9.14.4`
- `git 2.53.0`

另外，`~/.config/opencode/` 已经存在，但里面还没有 `plugins/` 和 `skills/` 目录。

也就是说，前置条件其实已经齐了，剩下的问题只剩一个：到底先装什么。

## 如果只是想先把 skill 跑起来，其实很简单

如果目标只是先摸清这套生态，最小可用路线其实并不复杂。

先看有哪些可用 skill：

```bash
npx skills add vercel-labs/agent-skills --list
```

如果确认要装到 OpenCode 全局目录：

```bash
npx skills add vercel-labs/agent-skills -g -a opencode
```

如果不想一次装一大堆，也可以先只挑几个：

```bash
npx skills add vercel-labs/agent-skills -g -a opencode \
  --skill web-design-guidelines \
  --skill react-best-practices
```

看到这里的时候，我其实已经有一个感觉了：公共 skill 更像是通用方法库，但真正长期有用的，多半还是你自己的那份约定，比如项目结构、提测流程、依赖选择习惯、代码风格之类的。那种东西如果写成自己的 `project-conventions`，对日常使用反而更直接。

## 后面我开始纠结两个更具体的仓库

真正让我停下来想一想的，是这两个：

::github{repo="obra/superpowers"}

::github{repo="OthmanAdi/planning-with-files"}

这两个仓库都不只是“给 agent 塞几条建议”那么简单，它们更像是在定义一整套工作方式。

也正因为这样，我很快就意识到：第一次接触 skill，如果把两套都一起装进去，大概率不会是 1 + 1 > 2，反而更可能是谁都想接管流程，最后体验变乱。

## 为什么我最后更偏向 `superpowers`

`superpowers` 给我的感觉，是它更适合作为“第一次给 OpenCode 加 skill”的起点。

它不是一个单点 skill，而是一整组互相配合的东西，比如：

- `brainstorming`
- `writing-plans`
- `systematic-debugging`
- `verification-before-completion`
- `requesting-code-review`

光看这些名字，其实就差不多能知道它想解决什么问题了：不是只帮你“回答得更像专家”，而是试图让 agent 在开发过程中更有章法。

这套思路我挺能接受，因为它解决的是日常高频场景：

- 开始写之前，先把需求说清楚
- 复杂改动别一头扎进去，先拆计划
- 调 bug 的时候别瞎试，走系统化排查
- 做完别急着宣布结束，先验证

这些东西不是那种“偶尔会用到”的能力，而是几乎每天都会碰到的工作流。

还有一个很现实的点：`superpowers` 对 OpenCode 的接入说明写得比较完整。仓库里专门有 OpenCode 的安装文档，不是那种“理论兼容，但你自己猜怎么接”的状态。

## `planning-with-files` 我为什么决定先不装

说实话，我并不是觉得 `planning-with-files` 不好。

相反，我其实挺喜欢它的核心思路：把复杂任务过程写进文件里，而不是全堆在上下文窗口里。

它的中心做法很清楚，就是围绕三个文件组织任务：

- `task_plan.md`
- `findings.md`
- `progress.md`

这个思路对长任务特别有吸引力，尤其是下面这些情况：

- 任务会跨很多轮对话
- 中间可能清上下文
- 研究、排查和尝试过程很多
- 希望过程本身能留档

但问题也很直接：它自己文档里对 OpenCode 的支持等级写的是 `Partial Support`。

这就意味着，它不是不能用，而是有些亮点能力在 OpenCode 上未必能完整跑起来。尤其是它对 hooks 的依赖比较明显，而 OpenCode 在这一块并没有 Claude Code 那么完整。

所以我的判断就变得很现实：

- 如果我已经很明确需要“文件化规划”这套方法，那它值得装
- 但如果我现在只是第一次接 skill，先装它不一定最划算

## 最后我决定先只装 `superpowers`

我后来把目标收得很小：这一步不是为了打造终极 agent 环境，而是先把 skill 这件事真正接进来，并且尽快感受到它对日常使用的影响。

在这个前提下，`superpowers` 更适合作为第一步。

原因很简单：

- OpenCode 接入路径更清楚
- 覆盖的是更高频的日常开发动作
- 用起来不用先改变我原本的任务管理习惯
- 就算以后再加别的 skill，它也比较像底层工作流增强，而不是另起一套系统

至于 `planning-with-files`，我准备等自己真的出现这类需求时再加：

- 经常做跨天任务
- 经常需要恢复上下文
- 确实想把计划和发现长期落盘

那时候再装，它的价值会更明确。

## 我最后保留下来的 `superpowers` 安装步骤

结合它给 OpenCode 的安装说明，我最后整理出来的最小命令就是这几条：

```bash
git clone https://github.com/obra/superpowers.git ~/.config/opencode/superpowers

mkdir -p ~/.config/opencode/plugins ~/.config/opencode/skills

rm -f ~/.config/opencode/plugins/superpowers.js
rm -rf ~/.config/opencode/skills/superpowers

ln -s ~/.config/opencode/superpowers/.opencode/plugins/superpowers.js ~/.config/opencode/plugins/superpowers.js
ln -s ~/.config/opencode/superpowers/skills ~/.config/opencode/skills/superpowers
```

做完之后，重启 OpenCode 就可以。

如果后面要更新，也很直接：

```bash
git -C ~/.config/opencode/superpowers pull
```

## 我会怎么验证它到底有没有装对

我现在越来越喜欢把验证步骤写得很明确，因为这种事情最怕的不是失败，而是“看起来像成功了，但其实自己心里没底”。

第一步，先确认两个链接在不在：

```bash
ls -l ~/.config/opencode/plugins/superpowers.js
ls -l ~/.config/opencode/skills/superpowers
```

第二步，重启 OpenCode，开新会话。

第三步，直接问几个比较容易看出差异的问题：

- `do you have superpowers?`
- `help me plan this feature`
- `debug this issue systematically`

如果它明显开始表现出那种“先澄清、再规划、最后验证”的节奏，基本就说明接进来了。

## 这次折腾对我最大的改观

我这次最大的改观其实不是“原来 skill 有这么多仓库”，而是我开始更清楚地意识到：skill 不是单纯给 agent 叠知识点，它更像是在叠工作方式。

模型本身当然重要，但很多时候真正影响结果的，是这些更具体的东西：

- 它有没有被提醒先做规划
- 它有没有被提醒别跳过验证
- 它有没有机会读取你自己的约定
- 它是不是能把一套有效的方法复用下去

从这个角度看，skill 更像是在给 agent 加“做事习惯”，而不是只加“知道什么”。

## 我接下来大概会怎么继续折腾

我现在的打算也很朴素。

先只装 `superpowers`，用一阵子，看看它到底会不会真的改变我平时在 OpenCode 里的工作节奏。如果效果明显，下一步我大概率会做两件事：

- 补一个自己的本地 skill，比如 `project-conventions`
- 等真的遇到长任务，再考虑加 `planning-with-files`

这样至少不会在一开始就把系统堆得太满。

回头看，我现在对 skill 这件事的态度反而简单了很多：先搞清楚边界，再做最小可用接入，有明确痛点的时候再继续加复杂度。

对我来说，第一次接触 OpenCode skill，先从 `superpowers` 开始，刚刚好。
