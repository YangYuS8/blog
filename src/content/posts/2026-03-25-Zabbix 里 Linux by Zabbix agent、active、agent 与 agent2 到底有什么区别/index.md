---
title: "Zabbix 里 Linux by Zabbix agent、active、agent 与 agent2 到底有什么区别"
urlSlug: '20260325-02'
published: 2026-03-25
description: '系统梳理 Zabbix 中 Linux by Zabbix agent、Linux by Zabbix agent active、zabbix-agent 与 zabbix-agent2 这四个概念的区别，以及实际部署时该如何选择。'
image: ''
tags: ['Zabbix', 'Linux', '运维', '监控']
category: '运维实践'
draft: false 
lang: 'zh_CN'
---

在刚开始接触 Zabbix 的时候，我觉得最容易让人混乱的，不是页面按钮，也不是触发器表达式，而是下面这四个名字：

- `Linux by Zabbix agent`
- `Linux by Zabbix agent active`
- `zabbix-agent`
- `zabbix-agent2`

看起来它们都叫 “agent”，但其实并不是同一个维度的东西。

如果这几个概念没分清，后面在给主机选模板、判断为什么界面里会出现“地址未知”、或者 deciding 到底该用主动还是被动采集时，就很容易越看越乱。

这篇文章就专门把这四个概念拆开讲清楚，并给出实际部署时更容易落地的选择思路。

## 先说结论：这是两组完全不同维度的概念

最简单的理解方式是：

### 第一组：模板
- `Linux by Zabbix agent`
- `Linux by Zabbix agent active`

这两个是 **模板（Template）**。

它们决定的是：

- 监控项怎么设计
- 采集走主动还是被动
- 包含哪些 key
- 触发器、图形、自动发现怎么组织

### 第二组：程序
- `zabbix-agent`
- `zabbix-agent2`

这两个是 **真正安装在主机上的 agent 程序**。

它们决定的是：

- 机器上到底跑的是哪个客户端
- 由谁来响应检查、回传数据
- 支持哪些能力、插件和实现方式

如果只记一句话，我会记这个：

> **模板决定“怎么监控”，程序决定“谁在执行监控”。**

## `Linux by Zabbix agent` 和 `Linux by Zabbix agent active` 是什么

这两个名字很像，但差异点不在“支持哪个二进制”，而在：

> **监控项默认是按被动模式设计，还是按主动模式设计。**

### `Linux by Zabbix agent`
这套模板更偏向 **被动模式（passive checks）**。

也就是说：

- Zabbix server 会主动去连 agent
- 从 agent 那里拉数据
- 因此在主机可用性界面里，通常能看到明确的 agent 接口状态
- 比如：
  - `100.64.0.1:10050 可用`

这类模板更适合：

- server 能直接打到主机的环境
- 内网 / 局域网 / tailnet 内部网络
- 希望在面板里明确看到接口可用性状态

### `Linux by Zabbix agent active`
这套模板更偏向 **主动模式（active checks）**。

也就是说：

- agent 自己主动连回 Zabbix server
- 把数据回传给 server
- server 不再依赖主动去探测 agent 接口

这种情况下，界面里常见的现象就是：

- 主动检查：可用
- 地址：未知

这不是故障，而是因为：

> server 并没有真的在做被动接口探测，所以接口状态自然不会像被动模式那样明确显示。

这类模板更适合：

- NAT 后面的机器
- server 不方便直接访问 agent 的机器
- 跨网段、复杂网络环境
- 想让主机自己主动回连监控中心的场景

## `zabbix-agent` 和 `zabbix-agent2` 又是什么

如果说前两个是“监控策略层”的概念，那这两个就是“执行层”的概念。

### `zabbix-agent`
这是比较经典的老一代 agent。

它的特点可以概括成：

- 历史更久
- 很多旧部署都围着它构建
- 功能稳定、思路传统
- 但扩展能力和现代化程度相对有限

### `zabbix-agent2`
这是更新一代的 agent。

它的特点通常是：

- 官方现在更偏向推荐的新实现
- 架构更新
- 扩展和插件能力更强
- 对一些新场景支持更好
- 后续维护通常更舒服

所以如果是新装环境，很多情况下会优先考虑 `zabbix-agent2`。

## 模板和 agent 程序不是一一绑定关系

这是最容易误解的一点。

很多人第一次看到名字时会下意识觉得：

- `Linux by Zabbix agent` 是给 `zabbix-agent` 用的
- `Linux by Zabbix agent active` 是给 `zabbix-agent2` 用的

其实并不是这样。

更准确地说：

- `Linux by Zabbix agent` 说的是 **被动采集方式**
- `Linux by Zabbix agent active` 说的是 **主动采集方式**

它们本质上描述的是：

> **监控项的工作方式**

而不是：

> **一定绑定某一个二进制程序名**

换句话说，真正决定你应该用哪个模板的，首先是：

- 网络环境
- server 和主机之间的连通性
- 你希望看到什么样的可用性状态

而不是你机器上装的是 `agent` 还是 `agent2`。

## 为什么会出现“主动检查可用，但地址未知”

这个现象其实很能帮助理解“模板”和“agent”不是一回事。

比如一台主机套的是：

- `Linux by Zabbix agent active`

面板里可能会看到：

- 主动检查：可用
- 地址：未知

这并不代表 agent 程序坏了，也不代表配置一定有问题。

它更常见的含义是：

- agent 正在主动向 server 上报数据
- 但 server 没有对 agent 做被动接口探测
- 所以接口状态显示为未知

如果同一台主机换成：

- `Linux by Zabbix agent`

那么 server 会主动探测：

- `IP:10050`

这时候界面里就更容易看到明确的：

- 可用
- 不可用
- 端口或地址异常

这也是为什么很多人在“active 明明正常，为什么地址未知”这个问题上会困惑。

根本原因不是 agent 本体，而是：

> **模板选的是 active，所以界面展示的重点就不是被动接口状态。**

## 那实际部署时到底该怎么选

说到这里，最实用的问题其实是：

> 到底什么时候该选 `Linux by Zabbix agent`，什么时候该选 `Linux by Zabbix agent active`？

我自己现在更倾向于这样判断。

### 适合选 `Linux by Zabbix agent` 的场景

如果满足这些条件：

- Zabbix server 能直接访问主机
- 主机就在内网 / tailnet / 可达网络中
- 不存在复杂 NAT 阻断
- 希望界面里看到明确的 agent 接口可用性

那么更适合选：

- **`Linux by Zabbix agent`**

它的优点是：

- 逻辑更直观
- 面板上更容易一眼看清楚接口是否正常
- 排查 10050 端口、接口连通性时更省心

### 适合选 `Linux by Zabbix agent active` 的场景

如果是这些情况：

- server 不方便直接访问 agent
- 主机在 NAT 后面
- 网络拓扑复杂
- 想让 agent 主动回连 server

那么更适合选：

- **`Linux by Zabbix agent active`**

它的优点是：

- 对网络要求更低
- 不需要 server 主动打穿到主机
- 在复杂网络环境下更容易稳定工作

它的代价则是：

- 界面里可能会看到“地址未知”这种表现
- 可用性展示不如被动模式直观

## 那能不能同时用

理论上，主动和被动模式是可以同时存在的。

但在实际 Zabbix 模板层面，如果你直接把：

- `Linux by Zabbix agent`
- `Linux by Zabbix agent active`

同时挂到同一台主机上，往往会报冲突。

原因很简单：

- 这两个模板里有很多重复监控项
- 比如会有相同 key 的项目（例如 `agent.hostname`）
- Zabbix 不允许一台主机同时继承同一个 key 的两份监控项

所以“主动 + 被动混合”并不是简单地把两个官方模板都打上去就结束了。

如果真要混合，通常有两种做法：

### 做法 1：二选一
对大多数主机，其实直接选一种就够了。

### 做法 2：做自定义模板
以其中一个模板为主，再从另一个模板里手动挑一些需要的监控项，做去重后的自定义模板。

这才是更专业、但也更麻烦的做法。

## 对 `agent2` 的建议

如果是新装环境，我自己的倾向通常是：

- **优先装 `zabbix-agent2`**

原因很简单：

- 它更现代
- 扩展能力更强
- 后续维护和兼容性通常更好

但这并不代表：

- 你装了 `agent2` 就必须用 `Linux by Zabbix agent active`

这是两个不同维度的问题。

更准确的关系应该是：

- `agent2` 只是你在主机上选用的执行程序
- 模板到底选 passive 还是 active，还是要看网络环境和监控需求

## 如果让我给一个最简单的选择策略

我会把它压成下面这张脑内速查表。

### 一、先看你选的是什么层

#### 模板层
- `Linux by Zabbix agent` → 被动采集为主
- `Linux by Zabbix agent active` → 主动采集为主

#### 程序层
- `zabbix-agent` → 老 agent
- `zabbix-agent2` → 新 agent

### 二、再看你的网络现实

#### server 能直接访问主机
优先考虑：
- `Linux by Zabbix agent`

#### server 不方便访问主机
优先考虑：
- `Linux by Zabbix agent active`

### 三、再看你是否在意界面里的接口可用性显示

#### 在意
优先考虑：
- 被动模板

#### 不在意，只要数据能上来
主动模板也完全可以接受。

## 最后的结论

如果只用一句话总结这四个名字的区别，我会这样说：

> `Linux by Zabbix agent` 和 `Linux by Zabbix agent active` 是 **模板**，说的是“怎么采集”；
> `zabbix-agent` 和 `zabbix-agent2` 是 **程序**，说的是“谁在执行采集”。

它们有关联，但不是一一绑定关系。

真正决定该选哪个模板的，不是你装的是 `agent` 还是 `agent2`，而是：

- server 能不能直接访问这台主机
- 你希望界面里看到怎样的可用性状态
- 这台主机的网络环境到底是简单还是复杂

把这件事分清之后，再看 Zabbix 里的模板选择，思路就会清楚很多。