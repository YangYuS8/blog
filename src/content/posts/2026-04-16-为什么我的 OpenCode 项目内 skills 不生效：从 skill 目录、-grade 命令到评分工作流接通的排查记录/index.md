---
title: "为什么我的 OpenCode 项目内 skills 不生效：从 skill 目录、/grade 命令到评分工作流接通的排查记录"
urlSlug: '20260416-01'
published: 2026-04-16
description: '一篇实践记录：我在给 OpenCode 搭一套基于 issue 的自动评分流程时，为什么最开始明明写了 skill 却不生效，后来又为什么发现 /grade 也不会自己出现，以及最后是怎么把项目内 skills、commands 和评分仓库结构理顺的。'
image: ''
tags: ['OpenCode', 'AgentSkills', 'GitHub', '自动化', '实践记录']
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

这两天我在折腾一套给学生作业自动评分的流程。

目标其实很明确：

- 学生通过 GitHub issue 提交自己的任务仓库
- 我在本地进入评分仓库
- 启动 OpenCode
- 直接执行 `/grade <issue编号>`
- 然后让 OpenCode 自动完成：
  - 读取 issue
  - 判断这是哪一道题
  - 选择对应评分 skill
  - clone 学生仓库
  - 评分
  - 把结果回复到 issue
  - 写入 CSV
  - 更新排行榜
  - 关闭 issue

这个目标看起来挺顺，但真正做的时候，我还是踩了几轮坑。

而且最坑的一点是：

**很多问题不是“不会写 skill”，而是“你以为会自动生效的东西，其实根本不是这么加载的”。**

所以这篇我不写成教程，而是按真实排查过程记录一下，省得以后自己再踩一次。

## 一开始，我以为只要把 skill 放进仓库就够了

我最早搭评分仓库的时候，思路很直接：

- 每道题一个评分 skill
- 再加一个总入口 skill
- 仓库根目录直接放这些 skill 文件夹

当时仓库大概长这样：

```text
dev-2026-grading/
├── assessment-html-css-beginner/
├── assessment-js-api-beginner/
├── assessment-python-data-cleaning-beginner/
├── assessment-python-deepseek-cli-beginner/
├── assessment-python-tcp-beginner/
└── grade-submission/
```

我当时的预期非常朴素：

> 既然 skill 都在仓库里了，那 OpenCode 进来应该就能看见，然后直接用。

结果不是。

## 第一个问题：skill 根本没按预期被项目识别

后来排查的时候我才反应过来，问题根本不在 skill 内容，而在于：

**项目内 skills 的位置不对。**

我去查了 OpenCode 相关说明之后，才意识到它看项目内 skill，通常更偏向这些目录：

```text
.opencode/skills/
.claude/skills/
.agents/skills/
```

也就是说，像我一开始那样把 skill 平铺在仓库根目录，很多时候 OpenCode 根本不会把它们当成“项目内 skills”。

这个坑其实挺典型的，因为你会产生一种错觉：

- 文件都在
- `SKILL.md` 也写了
- frontmatter 也有

那为什么还不生效？

答案是：

> **因为它没在 OpenCode 预期的项目内 skill 目录里。**

所以我后面做的第一轮关键调整，就是把整个评分仓库改成：

```text
dev-2026-grading/
└── .opencode/
    └── skills/
        ├── assessment-html-css-beginner/
        ├── assessment-js-api-beginner/
        ├── assessment-python-data-cleaning-beginner/
        ├── assessment-python-deepseek-cli-beginner/
        ├── assessment-python-tcp-beginner/
        └── grade-submission/
```

改完这一步以后，OpenCode 里至少已经能看到这些 skills 了。

## 第二个问题：我能看到 skills，但 `/grade` 还是没有

这一步其实更容易让人误判。

因为当我看到 skills 已经能被识别的时候，第一反应是：

> 好，那现在应该就可以直接 `/grade 12` 了吧？

结果还是不行。

skills 在，`/grade` 却没有。

这时候我才继续去查，最后发现另一个关键事实：

> **skill 不会自动变成 slash command。**

这一点如果没搞清楚，真的很容易一直在错误方向上优化 skill 本身。

实际上在 OpenCode 里，这两件事不是一回事：

### skill 负责什么
skill 负责的是：

- 这件事该怎么做
- 评分标准是什么
- 路由逻辑是什么
- 输出格式是什么

### command 负责什么
command 负责的是：

- `/grade` 这个命令入口从哪里来
- 用户输入 `/xxx` 后，到底展开成什么 prompt / workflow

也就是说：

- `.opencode/skills/` 负责能力
- `.opencode/commands/` 负责命令入口

我当时就是把这两个概念混在一起了。

## 所以 `/grade` 的真正修法，不是继续改 skill，而是补 command

后来我就把仓库继续改成这样：

```text
dev-2026-grading/
└── .opencode/
    ├── skills/
    │   ├── assessment-html-css-beginner/
    │   ├── assessment-js-api-beginner/
    │   ├── assessment-python-data-cleaning-beginner/
    │   ├── assessment-python-deepseek-cli-beginner/
    │   ├── assessment-python-tcp-beginner/
    │   └── grade-submission/
    └── commands/
        └── grade.md
```

`grade.md` 这一步补上以后，逻辑才终于闭环：

- `skills` 负责评分能力
- `commands` 负责 `/grade` 入口

也就是说，`/grade` 不是 skill 自己长出来的，而是要显式给它一个 command。

这一步想明白以后，整个仓库结构一下子就清楚了很多。

## 第三个问题：仓库里会不会混进一堆“过渡文件”

这件事在重构过程中也特别容易发生。

比如我在前面几轮里，其实做过一些过渡方案：

- 用 Python 写过一个自动评分流程骨架脚本
- 做过旧版 router skill
- README 里一度同时混着学生说明和 agent 说明

这些东西在“还没定型”的时候当然有帮助，但一旦方向已经明确，就会开始制造干扰。

尤其是当目标已经收敛成：

> **专门对接 OpenCode，skill-first，Node 只做机械辅助脚本**

那之前那些过渡实现继续留着，只会让后来的人看不懂到底哪个才是主流程。

所以后面我又做了一轮比较狠的清理：

- 删掉旧的过渡脚本
- 删掉旧的 router 结构
- README 只保留给学生看的提交说明
- 面向 agent 的说明全部拆到 `docs/` 里
- 把 CSV 更新和排行榜生成收敛成单独的 Node 脚本

## 最后收敛下来的评分仓库结构

我最后比较满意的一版，大概是这样：

```text
dev-2026-grading/
├── .github/
│   └── ISSUE_TEMPLATE/
│       └── submission.yml
├── .opencode/
│   ├── skills/
│   │   ├── assessment-html-css-beginner/
│   │   ├── assessment-js-api-beginner/
│   │   ├── assessment-python-data-cleaning-beginner/
│   │   ├── assessment-python-deepseek-cli-beginner/
│   │   ├── assessment-python-tcp-beginner/
│   │   └── grade-submission/
│   └── commands/
│       └── grade.md
├── docs/
│   ├── agent-notes.md
│   ├── grade-command-template.md
│   ├── opencode-workflow.md
│   └── ranking.md
├── results/
│   └── grades.csv
├── scripts/
│   ├── update_grades_csv.js
│   └── build_leaderboard.js
└── README.md
```

这个结构我现在觉得比较舒服，原因也很简单：

### 学生看什么
学生只需要看：

- `README.md`
- issue 模板

### agent / 操作者看什么
agent 或操作员只需要关心：

- `.opencode/skills/`
- `.opencode/commands/`
- `docs/opencode-workflow.md`
- `docs/agent-notes.md`

### 脚本只负责什么
脚本只做两件机械事：

- 追加写入 CSV
- 生成排行榜

这就比“所有东西都混在 README 里”清楚太多了。

## 还有一个容易忽略的小坑：GitHub issue 表单字段也不能乱写

在做这套评分仓库的时候，我还遇到过一个看起来小，但其实挺烦的坑。

当时我写 GitHub issue 模板，顺手加了一些自己以为合理的字段，结果直接报错：

- `message is not a permitted key`
- `Description can't be blank`

后来才反应过来，这一块也不能靠“差不多就行”，而是要老老实实按 GitHub 官方 Issue Forms 的 schema 来。

所以后面我把模板改成了标准结构，只保留官方支持的这些：

- `name`
- `description`
- `title`
- `labels`
- `body`

在 `body` 里再用：

- `markdown`
- `input`
- `dropdown`
- `textarea`

以及：

```yaml
validations:
  required: true
```

这一类官方支持的校验方式。

这个经验也挺重要的，因为整条评分流程本来就依赖 issue 模板，如果模板本身有问题，后面 skill 再漂亮也白搭。

## 这件事最后让我想明白的一点

我觉得这次排查最有价值的地方，不是“终于让 skills 出现了”，而是把下面这三个层次彻底分开了：

### 第一层，skill
负责“这件事怎么做”。

### 第二层，command
负责“用户怎么触发这件事”。

### 第三层，script
负责“那些机械、确定、适合脚本化的收尾动作”。

如果这三层一开始没分清楚，就很容易出现下面这些问题：

- 明明是 command 的问题，却一直在改 skill
- 明明是目录结构的问题，却一直怀疑 prompt 不够好
- 明明是脚本适合做的事情，却硬塞进 skill 里

而一旦这三层理顺，整件事就会突然变得很顺。

## 写在最后

如果你也在给 OpenCode 搭项目内 skills，而且碰到了这种情况：

- skill 明明写了，但没生效
- skill 能看到，但 `/xxx` 命令没有
- 仓库越改越乱，不知道哪个才是主流程

那我现在最建议先检查的就是这三件事：

### 1. skill 是不是放在项目内正确目录
例如：

```text
.opencode/skills/
```

### 2. 你缺的是不是 command，而不是 skill
例如：

```text
.opencode/commands/grade.md
```

### 3. 机械收尾动作是不是应该拆成脚本
例如：

- 写 CSV
- 生成排行榜

这三件事想清楚以后，整个 OpenCode 项目内 skill 的工作流就会稳定很多。

至少对我这次来说，真正把评分仓库接顺，靠的不是“继续写更长的 skill”，而是：

> **把目录结构、命令入口和职责边界先理顺。**

这一步走顺了，后面才谈得上自动评分、issue 回帖和排行榜。