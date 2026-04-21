---
title: "ELK 和 EFK 是什么，应该怎么理解和部署：更贴近 Kubernetes 的一篇日志系统入门"
urlSlug: '20260420-03'
published: 2026-04-20
description: '一篇更贴近 Kubernetes / k3s 场景的日志系统入门文章：ELK 和 EFK 到底分别是什么、为什么在 K8s 里更常见的是 EFK、各组件分别负责什么，以及在单机 k3s 里应该怎样用更成熟的思路理解和部署它。'
image: ''
tags: ['ELK', 'EFK', 'Elasticsearch', 'Fluent Bit', 'Fluentd', 'Kibana', 'Kubernetes', 'k3s', '日志', 'DevOps']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你开始往 Kubernetes、k3s、SRE 或云原生方向学习，日志系统这件事迟早绕不过去。

最开始很多人接触到的是一个经典名词：

- **ELK**

也就是：

- **Elasticsearch**
- **Logstash**
- **Kibana**

但你如果继续往 Kubernetes 里看教程，很快又会发现，大家更常提的是：

- **EFK**

也就是：

- **Elasticsearch**
- **Fluentd / Fluent Bit**
- **Kibana**

所以真正容易让人困惑的问题其实不是“ELK 是什么”，而是：

> **为什么明明说日志系统常见是 ELK，但到了 Kubernetes 里，很多人又开始讲 EFK？**

这篇文章我就不再按特别轻的 Docker 入门路线去讲，而是把重点放在：

- ELK 和 EFK 分别是什么
- 它们各自适合什么场景
- 为什么 Kubernetes / k3s 里更常见 EFK
- 如果是单机 k3s 实验环境，怎样用更成熟的思路理解和部署它

## 先说结论

如果你是在学：

- Linux 日志系统
- 传统多机日志集中管理
- 通用日志处理链路

那先理解 **ELK** 很有价值。

但如果你是在学：

- Kubernetes
- k3s
- 容器日志采集
- 云原生里的日志系统

那我会更建议你把重点放在：

- **EFK**

因为它更贴近现在容器平台里的实际做法。

## ELK 和 EFK 到底分别是什么

### ELK
指的是：

- **Elasticsearch**：存储、索引、检索日志
- **Logstash**：采集、处理、转换日志
- **Kibana**：查询和展示日志

这是一套非常经典的组合。

### EFK
通常指的是：

- **Elasticsearch**：存储、索引、检索日志
- **Fluentd 或 Fluent Bit**：采集和转发日志
- **Kibana**：查询和展示日志

这里最关键的变化，其实就是：

> **把 Logstash 换成了 Fluentd / Fluent Bit。**

## 为什么 Kubernetes 里更常见的是 EFK，而不是 ELK

因为 Logstash 虽然强，但它相对更重。

在 Kubernetes 场景里，日志采集通常有几个要求：

- 组件尽量轻量
- 能够以 DaemonSet 形式铺在每个节点上
- 能比较自然地读取容器日志
- 能把 Kubernetes 元数据一起带上

这时候，Fluent Bit / Fluentd 通常就更合适。

尤其是：

- **Fluent Bit 更轻**
- **Fluentd 更成熟、插件更多**

所以在 Kubernetes 场景里，大家经常会选：

- Fluent Bit 做边缘采集
- Elasticsearch 做存储和索引
- Kibana 做查询

这就是为什么你会更常看到 EFK。

## 这几种组件分别负责什么

如果只抓主线，其实很好记。

### Elasticsearch 负责什么

它负责：

- 存日志
- 建索引
- 支持搜索
- 支持聚合分析

你可以把它理解成：

> **日志数据的仓库 + 搜索引擎。**

### Kibana 负责什么

它负责：

- 让你在 Web 页面里查日志
- 做 dashboard
- 做可视化
- 管理 data view

你可以把它理解成：

> **操作界面和分析界面。**

### Logstash 负责什么

它更像一个重型数据处理管道。

它适合：

- 做复杂解析
- 做字段提取
- 做格式转换
- 对接多种输入和输出

### Fluentd / Fluent Bit 负责什么

它们更像日志采集和转发层。

在 Kubernetes 场景里，常见做法是：

- 从 `/var/log/containers/*.log` 读容器日志
- 给日志补 Kubernetes 元数据
- 再发往 Elasticsearch

## 如果按一条最典型的数据流来理解

### ELK 常见思路

```text
应用日志 / 系统日志
    ↓
Logstash
    ↓
Elasticsearch
    ↓
Kibana
```

### EFK 常见思路

```text
容器 stdout/stderr 日志
    ↓
Fluent Bit / Fluentd
    ↓
Elasticsearch
    ↓
Kibana
```

这两条线的核心差异就在采集与处理层。

## 为什么我更建议在 k3s 里优先学 EFK

因为你现在更想贴近 Kubernetes。

而在 Kubernetes 里：

- 日志往往先走 stdout / stderr
- kubelet / container runtime 会把日志落到标准位置
- 日志采集器要按节点铺开
- 需要结合 Pod、Namespace、Container 元数据一起查

这些场景里，Fluent Bit / Fluentd 明显更顺手。

所以如果目标是：

- 学 Kubernetes 里的日志系统
- 学更贴近 SRE / DevOps / 平台工程的思路

那与其把大量精力花在 Logstash 上，不如先把：

- Elasticsearch
- Fluent Bit
- Kibana

这一套跑通。

## 在 k3s / K8s 里，一套更成熟的日志方案应该怎么理解

如果你是在单机 k3s 做实验，我建议用这种思路去理解。

### 第一层：日志产生

日志来自：

- Pod 里的应用输出
- 容器 stdout / stderr
- 节点上的系统日志（可选）

### 第二层：日志采集

由 Fluent Bit 这类采集器负责：

- 从节点读容器日志文件
- 解析基础格式
- 附加 Kubernetes 元数据
- 把日志发往后端

### 第三层：日志存储与检索

由 Elasticsearch 负责：

- 建索引
- 持久化
- 查询和聚合

### 第四层：日志查询与展示

由 Kibana 负责：

- 搜索日志
- 过滤字段
- 看不同 namespace / pod / container 的日志
- 做可视化和 dashboard

## 为什么单机 k3s 里也要按这种思路学

因为你现在虽然只是单机实验，但思路最好不要太偏。

如果你一开始就只学“在一台机器上随便起几个容器看看”，虽然也能跑，但以后迁移到更像实际环境的结构时，会很别扭。

更稳的方式是：

> **即使是单机，也尽量按 Kubernetes 里的组件职责来理解。**

也就是：

- 采集器按节点跑
- Elasticsearch 作为后端
- Kibana 作为前端

这样以后从单机 k3s 过渡到多节点，也不会完全推翻重来。

## Logstash 这时候还有没有价值

有。

但我会把它放在第二阶段去学。

因为 Logstash 更适合你在下面这些场景里深入：

- 日志格式很杂
- 需要复杂字段解析
- 需要多种输入输出
- 需要更重的处理逻辑

而如果你现在的目标是：

- 更贴近 Kubernetes
- 先把容器日志链路跑通

那我会优先建议你先把 EFK 跑通。

## 一套适合 k3s 学习的更成熟路线

如果按学习顺序来排，我会建议这样。

### 第一步：先把 Elasticsearch 和 Kibana 作为后端与前端理解清楚

你要先知道：

- Elasticsearch 负责什么
- Kibana 负责什么
- Kibana 里的日志为什么本质上来自 Elasticsearch

### 第二步：再理解 Fluent Bit / Fluentd 作为日志采集层

重点理解：

- 它从哪读日志
- 它怎么把日志送到 Elasticsearch
- 它怎么补 Kubernetes 元数据

### 第三步：再把它放进 k3s 环境里

也就是开始想清楚：

- 为什么采集器适合用 DaemonSet
- 为什么日志文件路径在节点上
- 为什么日志查询时 namespace / pod / container 信息很重要

## 如果你只是想做一套最小可用实验，应该怎么定目标

我建议不要一开始就追求“完整生产级日志平台”。

先把目标设成：

- Elasticsearch 起得来
- Kibana 起得来
- Fluent Bit 能采到容器日志
- Kibana 里能查到来自 Pod 的日志

这已经是一条很像样的 Kubernetes 日志链路了。

## 在 k3s 上部署时，什么叫“更成熟一些”

我觉得至少有这几个方向。

### 1）不要只盯着 Docker 单容器方式

如果你是为了学习 Kubernetes，单纯用：

- `docker run elasticsearch`
- `docker run kibana`

这种方式虽然也能理解组件，但它离 K8s 还是有点远。

### 2）尽量用 Kubernetes 对象或 Helm Chart 去理解

例如：

- Elasticsearch / Kibana 作为 K8s 里的工作负载
- Fluent Bit 用 DaemonSet 运行
- 通过 Service 暴露 Kibana
- 通过 values 管理部署方式

这比只停留在裸容器更贴近真实场景。

### 3）接受“日志系统本来就不轻”

这点要有心理预期。

无论 ELK 还是 EFK：

- Elasticsearch 都比较吃资源
- Kibana 也不算轻
- 日志一多，资源消耗会更明显

所以单机 k3s 里做实验时，重点应该放在：

- 理解链路
- 跑通结构
- 验证查询

而不是盲目追求大规模数据量。

## 你现在更应该重点学什么

如果目标是更贴近 Kubernetes，我建议把重点放在下面这些问题上：

### 1）容器日志到底存在哪里

### 2）Fluent Bit / Fluentd 是怎么采到这些日志的

### 3）Kubernetes 元数据是怎么被附加到日志里的

### 4）Elasticsearch 里最终的文档结构长什么样

### 5）Kibana 里怎么按 namespace / pod / container 查日志

这些点一旦弄清楚，你对 K8s 日志系统的理解会比“我会起几个容器”扎实得多。

## 如果真要在 k3s 里部署，我更建议怎样的思路

如果你准备开始动手，我更建议把部署思路定成这样：

### 1）Elasticsearch 和 Kibana 走更稳的 K8s 部署方式

也就是：

- 用 Helm 或 operator 思路去理解
- 至少把 Service、存储、资源限制、暴露方式想清楚

### 2）采集层优先选 Fluent Bit

原因很简单：

- 更轻
- 更贴近节点日志采集
- 对单机 k3s 更友好

### 3）先做“最小可查”，再做“更完整解析”

先做到：

- 日志能进 Elasticsearch
- Kibana 能看到
- 能按 namespace / pod 过滤

之后再考虑：

- 更复杂的 parser
- 更丰富的字段提取
- 更系统的索引与生命周期策略

## ELK 和 EFK 应该怎么选

如果简单粗暴一点说：

### 适合先学 ELK 的情况

- 你想先理解经典日志系统架构
- 你对传统日志处理链路更感兴趣
- 你后面可能要接触复杂日志清洗和转换

### 适合优先学 EFK 的情况

- 你主要想贴近 Kubernetes / k3s
- 你关心容器日志采集
- 你更想往云原生 / SRE 路线走

按你现在这个方向，我会更偏向后者。

## 写在最后

如果把这篇文章的重点压缩成一句话，我觉得最重要的是：

> **ELK 是经典日志系统思路，EFK 是更贴近 Kubernetes 场景的常见实现。**

对新手来说，理解 ELK 能帮助你建立日志系统的整体认知；但如果你的目标更偏向：

- Kubernetes
- k3s
- 云原生
- SRE / DevOps

那我会更建议你尽早把重点放到 EFK 这条线上。

因为它更接近你后面真正会遇到的日志链路。

如果后面继续写，我下一篇更值得展开的，其实已经不是“ELK 是什么”，而是：

> **如何在 k3s / Kubernetes 里，用更适合实验环境的方式部署一套最小可用的 EFK 日志系统。**
