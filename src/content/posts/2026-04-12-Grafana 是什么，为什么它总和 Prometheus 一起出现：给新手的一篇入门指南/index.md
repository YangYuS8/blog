---
title: "Grafana 是什么，为什么它总和 Prometheus 一起出现：给新手的一篇入门指南"
urlSlug: '20260412-02'
published: 2026-04-12
description: '一篇面向新手的 Grafana 入门文章：它到底是做什么的、为什么总和 Prometheus 搭配出现，以及新手应该怎么理解它在监控体系里的位置。'
image: ''
tags: ['Grafana', 'Prometheus', '监控', 'DevOps', '新手指南']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你刚开始接触监控，大概率会先听到两个名字：

- Prometheus
- Grafana

而且它们几乎总是一起出现。

很多新手一开始都会有点懵：

- Prometheus 不是已经能查数据了吗
- 为什么还要 Grafana
- 它到底是数据库、可视化工具，还是告警平台

这篇文章就专门讲 Grafana，而且尽量从新手视角出发，不拿一堆术语压你。

## 先用一句最简单的话理解 Grafana

**Grafana 是一个把监控数据“变成图表和面板”的工具。**

如果 Prometheus 更像是：

- 负责抓取数据
- 保存数据
- 允许你查询数据

那 Grafana 更像是：

- 负责把这些数据画出来
- 让你更直观地看趋势
- 把多种指标整理成一个能读懂的看板

你可以把它理解成：

> **Prometheus 更像仓库，Grafana 更像展示墙。**

## 为什么它总和 Prometheus 一起出现

因为它们的分工刚好互补。

### Prometheus 擅长“存和查”
例如：

- 当前 CPU 使用率
- 最近 5 分钟的请求总数
- 某个接口过去 1 小时的错误率

这些数据它都能查。

### Grafana 擅长“看和比较”
例如：

- 把 CPU、内存、磁盘同时放在一个页面上
- 看一整天、一整周的趋势
- 把多个服务做成一个 dashboard
- 用颜色、阈值、面板来快速识别异常

所以这两者放一起，刚好形成一条完整链路：

- Prometheus 采集和存储指标
- Grafana 负责展示和观察这些指标

## 如果没有 Grafana，会怎么样

其实你不用 Grafana，Prometheus 也不是不能用。

Prometheus 自己就有 Web UI，也能查指标，甚至也能画一些比较基础的图。

但问题是，Prometheus 自带界面更适合：

- 调试查询
- 临时看一个指标
- 验证某个 exporter 有没有工作

它不太适合长期做成一个“给人持续盯着看”的监控面板。

而 Grafana 在这方面就顺手很多。

## Grafana 最核心的价值是什么

对新手来说，我觉得 Grafana 最核心的价值不是“它很炫”，而是：

**它能让原本很抽象的监控数据变得一眼就能看。**

举个很简单的例子。

如果你在 Prometheus 里查：

```text
node_memory_MemAvailable_bytes
```

你会得到一个数字。

但如果你在 Grafana 里把它变成图表，再和：

- CPU
- 磁盘空间
- 网络流量

放在一起看，你就更容易发现：

- 是不是某个时间点一起出问题
- 内存是不是在稳定下降
- 机器变慢时，CPU 到底高不高

这就是 Grafana 真正好用的地方。

## Grafana 能接什么数据源

这是很多新手一开始没意识到的一点。

Grafana 不是只配 Prometheus 用的。

它可以接很多数据源，比如：

- Prometheus
- Loki
- Elasticsearch
- InfluxDB
- MySQL
- PostgreSQL
- Zabbix
- Tempo

也就是说，Grafana 本身不负责生产数据，它更像一个“通用可视化前端”。

所以你会看到它在很多团队里都很常见，因为只要数据源支持得好，它就能统一看很多东西。

## 对新手来说，先别贪多

虽然 Grafana 支持很多数据源，但你入门时完全没必要一下子全学。

最适合新手的路径还是：

> **先学 Grafana + Prometheus**

因为这套组合最常见，也最容易在 Linux 主机监控里看到成果。

## Grafana 里最常见的几个概念

如果你第一次打开 Grafana，最容易看到这些词：

- Data Source
- Dashboard
- Panel
- Query
- Alerting

你可以先这么理解。

### 1. Data Source

就是数据源。

例如你把 Prometheus 接进来，那 Prometheus 就是一个 Data Source。

### 2. Dashboard

就是仪表盘、看板。

一个 Dashboard 里可以放很多图。

例如一个主机监控面板里可以同时有：

- CPU 图
- 内存图
- 磁盘图
- 网络图

### 3. Panel

就是看板中的单个图块。

一个折线图是 Panel。
一个统计值卡片也是 Panel。
一个表格也可以是 Panel。

### 4. Query

就是你要查什么数据。

如果数据源是 Prometheus，那这里通常写的是 PromQL 查询。

### 5. Alerting

就是告警。

Grafana 现在也能做告警，但新手完全可以先不碰这一块，先学会做图就够了。

## 一个新手最容易理解的使用场景

假设你已经有了：

- 一台 Linux 主机
- `node_exporter`
- Prometheus

这时候你把 Grafana 接上 Prometheus，最常做的第一件事就是：

**导入一个主机监控 dashboard。**

然后你就能在一个页面里看到：

- CPU 使用率
- 内存占用
- 磁盘剩余空间
- 网络流量
- 系统负载

这一步做出来之后，你对 Grafana 的理解会比单纯看概念快很多。

## 为什么新手第一次看到 Grafana 会觉得“它比 Prometheus 更像监控系统”

因为 Grafana 更直观。

Prometheus 更像后台系统。

Grafana 更像前台展示层。

你真的每天打开看的，很多时候不是 Prometheus 自己的 UI，而是 Grafana 的面板。

所以很多人刚入门时会误以为：

> Grafana 才是监控系统本体。

其实不是。

更准确的说法是：

- Prometheus 负责指标的采集和存储
- Grafana 负责把这些指标组织成你看得懂的界面

## Grafana 能不能单独使用

能，但意义有限。

因为如果没有像 Prometheus 这样的数据源，Grafana 本身就没有多少东西可展示。

所以你通常不会只装 Grafana，而是把它和某种数据源搭配使用。

## 新手使用 Grafana 最容易踩的坑

### 1. 一上来就自己画复杂面板

其实没必要。

刚入门时最省力的方法是：

- 接上 Prometheus
- 找一个成熟的 Node Exporter Dashboard
- 先导入现成模板

先学会看，再慢慢学会自己做。

### 2. 把“图好看”当成重点

Grafana 的重点不是炫，而是让你更快发现问题。

真正有用的面板，不一定花哨，但一定要：

- 清楚
- 稳定
- 重点突出

### 3. 一开始就想做告警

Grafana 告警当然有用，但对新手来说，先把数据源、查询、图表理解清楚，比急着搞告警更重要。

## 新手最适合从哪里开始学 Grafana

我建议顺序是这样的：

### 第一步：先知道 Grafana 不是数据库

它不负责生成数据，也不负责长期存储指标。

它主要负责展示。

### 第二步：接一个 Prometheus 数据源

先别同时接一堆东西。

### 第三步：导入一个现成 Dashboard

例如最常见的 Node Exporter 主机监控模板。

### 第四步：尝试改一个小地方

比如：

- 改标题
- 改时间范围
- 改一个 Panel 的显示方式
- 新增一个简单图表

### 第五步：再学查询语句和告警

这样会比一开始就硬啃配置舒服很多。

## 一个最简单的理解方式

如果你现在还在分不清它和 Prometheus 的关系，我建议你先这样记：

- **Prometheus**：把数字收上来并存好
- **Grafana**：把数字画出来给人看

这个理解虽然简化，但对入门已经足够用了。

## 写在最后

如果你刚开始接触监控，我会建议你别把 Grafana 当成一个单独的复杂系统去学。

最好的入门方式其实很朴素：

1. 先让 Prometheus 抓到一台机器的指标
2. 再让 Grafana 连上 Prometheus
3. 找一个现成 dashboard 导入
4. 盯着图看一阵子

当你真的看到：

- CPU 什么时候高
- 内存什么时候涨
- 磁盘什么时候逼近上限

你就会明白 Grafana 真正的价值不是“画图好看”，而是它让你更容易理解系统到底在发生什么。
