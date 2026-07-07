---
title: "Project OS Skills：把 Agent 开发变成产品工程系统"
urlSlug: 'project-os-skills-product-engineering-os'
published: 2026-07-07
description: '记录一次从生产级项目中学到的开发思想：代码只是系统的一层，Agent 更应该围绕产品定位、工程边界、运维交付、测试和复盘形成长期工作流。'
image: ''
author: ""
tags: ["AI Agent", "Project OS Skills", "Agent Skills", "ADR", "工程实践"]
category: 'AI Agent 工作流'
draft: false
lang: 'zh_CN'
---

最近我接触了一个生产级项目。

出于隐私原因，这里不展开它的业务、客户、内部实现和具体代码。真正让我受到冲击的，也不是某个框架写法，或者某个特别炫的技术点，而是它背后那套开发节奏：先看产品闭环，再看工程边界；先把关键决策写下来，再让代码沿着这些决策生长；上线、回滚、测试和复盘不是最后补的文档，而是开发过程的一部分。

这件事有点颠覆我以前的习惯。

以前我做项目时，很容易把注意力放在“功能能不能跑起来”上。页面出来了，接口通了，构建过了，就会下意识觉得已经完成。但这次看完之后，我意识到：能跑只是第一层。一个项目如果想长期维护，真正重要的是它有没有自己的产品工程操作系统。

所以我把这套思路提炼成了一个开源 skills 包：

::github{repo="YangYuS8/project-os-skills"}

它不是某个项目的代码模板，也不是一组空泛的提示词，而是一套给 AI Agents 使用的工程方法包。目标很直接：让 Agent 不只是生成代码，而是像一个小型产品工程团队一样工作。

## 我以前的问题

我以前让 Agent 写代码时，经常会这样开始：

```text
帮我实现一个 xxx 功能。
```

然后 Agent 很快给出文件、组件、接口、脚本。短期看很高效，但后面经常会出现几个问题：

- 功能写出来了，但不知道它服务哪个用户场景。
- 架构选择是临时拍的，后面换人或者换 Agent 又要重新争论。
- 业务逻辑、接口处理、数据访问混在一起，改一个点会牵出一片。
- 隐藏 Prompt、规则、评分逻辑这类核心知识没有明确保护边界。
- 测试只在交付时跑一下，没有变成可复用资产。
- 排障修完就算，踩过的坑没有沉淀成知识库。

这些问题单独看都不致命，但叠在一起，项目就会慢慢变成一团“能跑但没人敢动”的代码。

这其实很像做衣服只看最后能不能穿，却不管版型、走线、面料和后续改衣空间。短期能交差，长期一定难看。

## 代码只是系统的一层

这次最大的改变，是我开始把项目拆成几个层次看：

```text
产品定位
 -> 护城河与知识系统
 -> ADR 架构决策
 -> 工程边界
 -> 黑盒与安全契约
 -> 运维交付
 -> QA 资产
 -> 复盘与知识库
```

以前我更关心“代码怎么写”。现在我会先问：

- 这个产品到底给谁用？
- 用户真正想完成的任务是什么？
- 这个项目的价值，是模型 API，还是背后的规则、流程和运营经验？
- 哪些东西必须留在服务端，不能暴露给普通用户？
- 哪些技术选择需要写成 ADR，避免以后反复争论？
- 部署失败怎么回滚？
- 测试能不能下次继续跑？
- 这次踩坑能不能变成下一次的诊断入口？

这些问题不会直接生成漂亮页面，但它们决定了项目后面能不能继续长。

## Project OS Skills 做了什么

`project-os-skills` 目前把这套思路拆成了几个独立 skills。

| Skill | 解决的问题 |
|---|---|
| `project-os-thinking` | 在写代码前先梳理产品定位、用户任务、系统边界、运维和知识沉淀 |
| `moat-first-ai-product` | 区分公开模型能力和真正可防守的产品 know-how |
| `adr-driven-architecture` | 把重要架构选择写成 ADR，留下上下文、取舍和回看条件 |
| `clean-boundary-engineering` | 让 UI、API、业务逻辑、持久化和脚本各自负责自己的层 |
| `blackbox-contract-security` | 用服务端 public/admin projection 保护内部 Prompt、规则、字段和凭证 |
| `runbook-first-ops` | 部署、迁移、排障前先有诊断、备份、变更、验证和回滚路径 |
| `qa-as-asset` | 把测试脚本、冒烟检查、回归清单变成长期资产 |
| `postmortem-knowledge-base` | 把事故、疑难排障和重复踩坑沉淀成知识库 |

我希望 Agent 以后不是一收到需求就冲去改文件，而是在合适的节点慢下来。

比如做新项目时，先用 `project-os-thinking` 看产品和系统；做 AI 产品时，用 `moat-first-ai-product` 找出真正的护城河；做架构选型时，用 `adr-driven-architecture` 留下为什么现在这样选；上线或改服务器时，用 `runbook-first-ops` 先写清楚风险和回滚。

这不是为了让开发变慢。恰恰相反，它是为了让后面的每一次迭代不必从零开始猜。

## 最触动我的几个思想

### 先看商业闭环，再写代码

很多 AI 项目一开始会陷在模型、框架和 UI 里。看起来很忙，但不一定知道用户为什么要用它。

我现在更认同一种顺序：先确认用户任务，再确认产品闭环，最后才是技术实现。

如果一个功能不能解释清楚“谁在什么场景下用它完成什么任务”，那它很可能只是技术展示。技术展示可以练手，但不能支撑一个长期项目。

### 护城河不是“我调用了强模型”

对 AI 产品来说，模型往往不是护城河。别人也可以调用同一个模型、同一个 API、同一个开源库。

真正值得保护的，通常是中间那层转换系统：

- 输入如何被规范化；
- 任务如何被拆解；
- 规则、配方、模板如何组合；
- 失败案例如何回流；
- 人工经验如何变成可维护知识；
- 哪些字段和规则永远不该被普通用户看到。

所以 `moat-first-ai-product` 的核心句子是：模型不是护城河，隐藏的转换层才是。

### 边界比炫技更重要

一个项目可以是单体，也可以很优雅。

关键不在于有没有微服务、消息队列、Kubernetes，而在于每层是否清楚：

- UI 负责展示和交互；
- API 负责鉴权、校验、限流、调用业务服务；
- 业务层负责编排规则、状态流转、补偿逻辑；
- 持久化层负责数据访问、迁移和一致性；
- 运维脚本负责部署、备份、诊断和回滚。

如果这些边界混在一起，Agent 写得越快，债也会堆得越快。

### 公开接口必须是契约，不是“前端不展示”

这点尤其重要。

如果普通用户不能看到某个字段，那 public API 就不应该返回它。不能指望“前端不渲染”来保护内部信息。

所以我在 skills 里单独放了 `blackbox-contract-security`，要求明确区分：

```text
Internal record -> public projection
Internal record -> admin projection
```

普通用户只拿 public projection。管理员才走 admin projection。隐藏 Prompt、规则、评分逻辑、供应商细节、内部错误和其他用户数据，都不能靠前端遮住。

### 测试和复盘不是交付截图

以前我容易把测试当成“这次证明我做完了”。现在我更倾向于把测试当成项目资产。

一次手工验证，只能证明当时看起来没问题。一个可重复运行的脚本、清单或 fixture，才能保护下一次改动。

复盘也一样。排障结束后，如果只留一句“已修复”，下次换个人还是要重新踩坑。好的复盘应该记录症状、影响、根因、修复、验证和预防措施，最后变成知识库入口。

这也是 `qa-as-asset` 和 `postmortem-knowledge-base` 想解决的问题。

## 怎么使用这个 skills 包

如果只是想给一个项目加上 Project OS 的工作流，推荐让 Coding Agent 自己安装。打开目标项目，把下面这段话交给 Codex、Claude Code、Cursor、Windsurf、OpenCode、Gemini CLI、Hermes 或其他 Agent：

```text
请按照下面这份安装指南，把 Project OS Skills 安装并配置到当前项目：
https://raw.githubusercontent.com/YangYuS8/project-os-skills/refs/heads/main/docs/guide/installation.md
```

Agent 会读取安装指南，根据当前项目选择安装模式，并帮助补全 `PROJECT_RULES.md`。

也可以直接在项目根目录执行：

```bash
curl -fsSL https://raw.githubusercontent.com/YangYuS8/project-os-skills/main/scripts/install.sh | bash -s -- --mode project --dest . --agents all
```

安装后，项目里会出现类似这些文件：

```text
.project-os/
PROJECT_RULES.md
AGENTS.md
CLAUDE.md
GEMINI.md
CODEX.md
OPENCODE.md
.cursor/rules/project-os.mdc
.cursorrules
.windsurfrules
```

其中 `.project-os/` 放通用方法和模板，`PROJECT_RULES.md` 记录当前项目自己的事实、约束、部署规则、测试要求和已知事故。

如果是 Hermes 这类支持原生 skills 目录的 Agent，也可以安装成原生 skills：

```bash
git clone https://github.com/YangYuS8/project-os-skills.git
cd project-os-skills
bash scripts/install.sh --mode skills --target hermes
```

## 我希望它改变什么

我不希望这个包变成另一堆漂亮但没人读的文档。

它应该改变的是 Agent 参与项目的方式：

- 不要一上来就写代码，先确认产品目标和用户任务。
- 不要把公开模型能力当成护城河，要找出自己的规则、流程和知识系统。
- 不要让架构选择散落在聊天记录里，重要决策要写 ADR。
- 不要把业务逻辑塞进页面或路由里，边界要清楚。
- 不要把敏感字段返回给前端再假装安全，public/admin 契约要分开。
- 不要把部署当成最后一步，诊断、备份、验证、回滚都属于工程本身。
- 不要把测试当成一次性报告，能复用的检查才是资产。
- 不要让事故只留下“修好了”，复盘应该让系统变聪明。

这套方法不会让一个粗糙想法自动变成好产品。但它会逼着 Agent 和人一起面对那些更难、也更真实的问题。

## 总结

这次经历给我的最大提醒是：开发不是把功能堆起来，而是让产品、工程、运维、测试和知识沉淀形成一个持续运转的系统。

`project-os-skills` 只是我目前提炼出的第一版。它肯定还会继续改，但方向已经很明确：让 AI Agent 从“代码生成器”往“产品工程协作者”靠近。

如果以后我再做 AI 产品或长期项目，我会优先把这套操作系统装进去。

不是为了显得专业，而是为了让项目在下一次需求、下一次部署、下一次事故之后，仍然能保持清醒。