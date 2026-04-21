---
title: "在 Kubernetes / k3s 里到底该学 ELK 还是 EFK：从日志链路到最小落地方案讲清楚"
urlSlug: '20260420-03'
published: 2026-04-20
description: '面向 Kubernetes / k3s 学习场景，直接讲清楚 ELK 和 EFK 在日志链路里的区别、为什么 K8s 里更常用 EFK、各组件在集群中分别负责什么，以及单机 k3s 更适合怎样的最小落地方案。'
image: ''
tags: ['ELK', 'EFK', 'Elasticsearch', 'Logstash', 'Fluent Bit', 'Kibana', 'Kubernetes', 'k3s', '日志', 'DevOps']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你是为了学 Kubernetes / k3s 里的日志系统，那最先该搞清楚的不是“ELK 是什么”这种泛概念，而是下面这件事：

> **Kubernetes 里的日志到底是怎么流动的，为什么很多人最后学的是 EFK，而不是传统 ELK。**

这篇我不再走那种很散的“组件介绍文”路线，而是直接回答几个更实际的问题：

- 在 K8s 里，日志从哪来
- 为什么很多场景不先选 Logstash
- Fluent Bit / Fluentd 在集群里到底干什么
- Elasticsearch 和 Kibana 在整条链路里处在什么位置
- 如果只是单机 k3s 学习，最小可用方案应该长什么样

## 先说结论

如果你的目标是：

- 学传统日志平台思路
- 学复杂日志清洗
- 学通用日志处理管道

那 ELK 值得懂。

但如果你的目标是：

- 学 Kubernetes / k3s
- 学容器日志采集
- 学更贴近 SRE / DevOps 的路线

那更应该优先学的是：

- **EFK**

原因不复杂：

> **在 Kubernetes 里，日志采集层通常更需要轻量、按节点铺开、天然适配容器日志，而这正是 Fluent Bit / Fluentd 更常见的原因。**

## ELK 和 EFK，真正差在哪

不是 Elasticsearch 变了，也不是 Kibana 变了。

真正变的是中间这层。

### ELK

```text
Elasticsearch + Logstash + Kibana
```

### EFK

```text
Elasticsearch + Fluentd / Fluent Bit + Kibana
```

也就是说：

- 后端存储还是 Elasticsearch
- 前端查询还是 Kibana
- **变化的是日志采集和处理层**

这也是理解这件事最重要的地方。

## 在 Kubernetes 里，日志从哪来

如果不先把这个问题想清楚，后面选工具就很容易乱。

在 Kubernetes 里，应用日志最常见的来源不是你手工指定的一堆文件路径，而是：

- 容器的 `stdout`
- 容器的 `stderr`

容器运行时会把这些日志写到节点上的标准位置，常见思路就是：

```text
应用容器输出日志
    ↓
容器运行时写入节点日志文件
    ↓
日志采集器从节点读取
    ↓
发给 Elasticsearch
    ↓
Kibana 查询
```

所以在 K8s 里，日志系统的核心不是“每个应用自己往哪里写”，而是：

> **节点上要有一个统一采集器，能把容器日志收走。**

这也是为什么 Fluent Bit / Fluentd 很适合用 DaemonSet 跑在每个节点上。

## 为什么在 K8s 里通常不把 Logstash 当第一选择

不是说 Logstash 不好，而是它在这个场景里经常不是最顺手的那个。

Logstash 的特点是：

- 功能强
- 配置灵活
- 解析能力重
- 输入输出插件多

但代价也很明显：

- 更重
- 更吃资源
- 作为 K8s 每节点采集器不够轻巧

而 Kubernetes 里的采集层，很多时候更需要：

- 轻量
- 稳定
- 易于铺开
- 能直接读容器日志
- 能带上 Pod / Namespace / Container 元数据

这时候 Fluent Bit / Fluentd 就更合适。

尤其是 Fluent Bit，很多人会把它当成：

> **更贴近 Kubernetes 边缘采集层的默认选项。**

## Fluent Bit 和 Fluentd 应该怎么理解

你可以先这么区分。

### Fluent Bit

偏轻量、偏采集、偏边缘。

适合：

- 在每个节点上做日志采集
- 资源敏感的环境
- 单机 k3s 或小型集群实验

### Fluentd

偏重一些，但插件生态更丰富。

适合：

- 更复杂的日志处理链路
- 更复杂的转发和转换需求

如果你现在是在学 k3s，我会更建议：

> **先用 Fluent Bit 建立对日志链路的理解。**

别一上来就把采集层搞得太重。

## Elasticsearch 在 K8s 里负责什么

这个反而最稳定。

它的职责始终比较明确：

- 存日志
- 建索引
- 支持检索
- 支持聚合分析

也就是说，无论你走 ELK 还是 EFK：

> **Elasticsearch 基本都是日志后端。**

但你在 K8s 里学它时，重点应该比单机环境多两层：

### 1. 它不是“装上就行”的服务

你还得考虑：

- 存储
- 资源限制
- 单节点还是多节点
- 是否需要持久化卷

### 2. 它是整套日志系统里最吃资源的部分之一

所以在单机 k3s 里做实验，不要一上来就追求太大的规模。

## Kibana 在 K8s 里负责什么

Kibana 的职责还是：

- 查询日志
- 按字段筛选
- 看 dashboard
- 做可视化

但放到 K8s 里，你真正要学的是：

- 怎么按 `namespace` 查
- 怎么按 `pod` 查
- 怎么按 `container` 查
- 怎么看某个应用的日志时间线

也就是说，Kibana 里最重要的不是“页面能打开”，而是：

> **你有没有把 Kubernetes 元数据一起带进日志里。**

如果没有这些字段，Kibana 的体验会差很多。

## 一条更贴近 Kubernetes 的日志链路应该长什么样

如果按你现在更该学的结构来说，我觉得最值得记住的是这一条：

```text
Pod 日志（stdout/stderr）
    ↓
节点上的容器日志文件
    ↓
Fluent Bit / Fluentd（DaemonSet）
    ↓
Elasticsearch
    ↓
Kibana
```

这条线里，每一层的职责都非常明确：

- Pod 负责产生日志
- 节点负责承接日志文件
- Fluent Bit 负责采集和附加元数据
- Elasticsearch 负责索引和存储
- Kibana 负责查询和展示

这比只背组件名有用得多。

## 如果是单机 k3s，最小可用方案应该怎么选

如果你只是为了学习，而不是立刻做生产日志平台，我会建议方案尽量收敛。

### 我更推荐的最小方案

- **Elasticsearch**：单实例
- **Kibana**：单实例
- **Fluent Bit**：DaemonSet

也就是一个典型的轻量 EFK 路线。

### 为什么这么选

因为它足够贴近 K8s，又不至于一上来就把复杂度拉满。

你真正需要先跑通的是：

1. Pod 能产生日志
2. Fluent Bit 能采到日志
3. Elasticsearch 能收到日志
4. Kibana 里能查到日志

只要这四步通了，这套学习路线就已经值了。

## 在单机 k3s 里，什么叫“更成熟一些”的部署思路

这里我说的“成熟”，不是生产级高可用，而是：

> **部署方式尽量贴近 Kubernetes 自己的工作方式，而不是只用几条 docker run 糊起来。**

我会优先建议这样理解。

### 1. Elasticsearch 和 Kibana 尽量按 K8s 工作负载来学

也就是：

- Deployment / StatefulSet 是什么角色
- Service 怎么暴露
- 存储怎么挂
- 资源限制怎么配

### 2. Fluent Bit 作为 DaemonSet 来学

这是这套日志链路里最有 Kubernetes 味儿的一层。

因为它能自然回答这些问题：

- 为什么是每个节点一个
- 它为什么能采到节点上的容器日志
- 它为什么适合做容器日志入口

### 3. 暴露 Kibana 时按 K8s 思路处理

例如：

- ClusterIP
- NodePort
- Ingress
- 反向代理

这个和你前面折腾 Grafana 的思路其实是类似的。

## 如果现在只是学习，哪些东西先别追太深

为了避免把自己绕死，我会建议你先别一开始就追这些：

- 复杂 Logstash filter
- 多节点 Elasticsearch 集群调优
- ILM / rollover / tiering
- 超大规模日志保留策略
- 特别复杂的 parser 和 pipeline

这些不是不重要，而是你现在先不需要靠它们建立第一层理解。

你更应该先把下面这些搞清楚：

- 日志怎么从 Pod 流出来
- 节点上的日志是谁采的
- 为什么采集器适合 DaemonSet
- Elasticsearch 为什么是后端
- Kibana 怎么体现 Kubernetes 元数据的价值

## 如果要在“学 ELK”和“学 EFK”之间做一个更直白的选择

我会这么说。

### 更适合先学 ELK 的情况

- 你想先学经典日志平台结构
- 你会碰很多传统主机日志
- 你后面想深入复杂日志处理

### 更适合先学 EFK 的情况

- 你主要目标是 Kubernetes / k3s
- 你要处理容器日志
- 你想更贴近云原生和 SRE 场景

按你现在的方向，明显更接近后者。

## 我觉得你现在最该学到什么程度

不是“我知道 ELK 和 EFK 的全称”，而是至少能把下面这段话自己讲出来：

> 在 Kubernetes 里，日志通常先从容器 stdout/stderr 出来，节点上会有对应日志文件；再由 Fluent Bit 这类 DaemonSet 采集器按节点收集日志，并附加 Kubernetes 元数据；日志进入 Elasticsearch 后可以被索引和检索；最后通过 Kibana 按 namespace、pod、container 等维度查询。

如果你能把这段链路讲顺，其实就已经比很多只会背名词的人强很多了。

## 写在最后

如果把这篇压缩成一句话，我觉得最值得记住的是：

> **ELK 是经典日志系统结构，EFK 是更贴近 Kubernetes 日志采集现实的常见路线。**

所以对你现在这种正在学 k3s / Kubernetes 的场景来说，更值得重点投入的不是“把 Logstash 先啃透”，而是：

- Fluent Bit / Fluentd 在 K8s 里怎么工作
- Elasticsearch 在日志链路里承担什么角色
- Kibana 怎么真正用来查容器日志

这才是更贴近你当前学习目标的路线。

如果下一篇继续写，我觉得真正该落地的就不是泛讲原理了，而是：

> **如何在单机 k3s 里部署一套最小可用的 EFK，并实际看到 Pod 日志进入 Kibana。**
