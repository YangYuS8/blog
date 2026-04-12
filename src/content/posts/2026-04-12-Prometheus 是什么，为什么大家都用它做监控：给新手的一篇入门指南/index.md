---
title: "Prometheus 是什么，为什么大家都用它做监控：给新手的一篇入门指南"
urlSlug: '20260412-01'
published: 2026-04-12
description: '一篇面向新手的 Prometheus 入门文章：它是什么、能做什么、和传统监控有什么区别，以及最基础的部署和使用方式。'
image: ''
tags: ['Prometheus', '监控', 'DevOps', 'Linux', '运维', '新手指南']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你刚开始接触服务器、容器、虚拟机或者 DevOps，很快就会遇到一个问题：

**我怎么知道我的服务现在是不是正常？**

比如：

- CPU 为什么突然飙高
- 内存是不是快吃满了
- 某个服务为什么会偶尔超时
- 磁盘空间还剩多少
- 某台机器到底什么时候开始变慢的

这些问题，本质上都指向同一件事：

> **你需要监控。**

而在现代监控体系里，Prometheus 基本算是最常见、也最值得新手尽早接触的一套工具。

这篇文章我会尽量用新手能接受的方式，讲清楚三件事：

1. Prometheus 到底是什么
2. 它平时是怎么工作的
3. 新手应该怎么开始部署和使用它

## Prometheus 是什么

先用一句不太严格、但很好理解的话来说：

**Prometheus 是一个专门用来采集、保存和查询监控指标的系统。**

关键词是：

- **采集**
- **保存**
- **查询**
- **指标（metrics）**

这里的“指标”，不是日志，也不是错误堆栈，而是更偏数字化、可度量的东西，例如：

- CPU 使用率
- 内存占用
- 磁盘剩余空间
- HTTP 请求总数
- 请求响应时间
- 某个接口 500 错误出现了多少次

Prometheus 最擅长做的事，就是把这些数字按时间持续记录下来，然后让你后面可以查：

- 现在是多少
- 五分钟前是多少
- 一小时内趋势如何
- 哪个时间点开始异常

## 它和“看日志”有什么区别

这是很多新手刚开始最容易混淆的地方。

### 日志更像“发生了什么”
例如：

```text
用户 A 登录成功
接口 /api/login 返回 500
数据库连接超时
```

日志擅长告诉你：

- 某件事发生了
- 它发生在什么时候
- 具体上下文是什么

### 指标更像“整体状态怎么样”
例如：

- 当前 QPS 是多少
- 过去 5 分钟错误率是多少
- 内存占用是不是一直在涨
- 平均响应时间是不是比昨天高

Prometheus 就属于后者。

所以你可以把它理解成：

- **日志**负责记录事件
- **Prometheus**负责记录数值趋势

它们不是互相替代，而是互补。

## Prometheus 为什么这么常见

Prometheus 受欢迎，不是因为它“高级”，而是因为它有几个非常实用的特点。

## 1）它的模型很清晰

Prometheus 的工作方式并不复杂，核心流程可以概括成：

1. 某个服务暴露自己的指标
2. Prometheus 定期去抓这些指标
3. 把结果按时间存下来
4. 你再通过查询语句把它们画成图或做告警

这套模型比很多新手想象的简单。

## 2）它很适合云原生和动态环境

如果你的服务是：

- Docker 容器
- Kubernetes Pod
- 多台 Linux 主机
- 微服务

Prometheus 会很好用，因为它本来就是为这种“节点会变化、服务会增减”的环境设计的。

## 3）它的数据模型非常适合运维场景

Prometheus 记录的是**时间序列数据**。

这意味着每一条指标都可以理解成：

> 某个数值，在某个时间点，处于什么状态。

例如：

- `node_cpu_seconds_total`
- `node_memory_MemAvailable_bytes`
- `http_requests_total`

只要你一旦开始看趋势图，就会明白这套模型为什么这么适合监控。

## Prometheus 是怎么工作的

如果你想入门，最重要的是先理解它的工作链路。

### 第一步：目标暴露指标

Prometheus 自己不凭空知道你的机器状态。

它需要有人把指标暴露出来。

例如：

- Linux 主机可以跑 `node_exporter`
- PostgreSQL 可以跑 postgres exporter
- MySQL 可以跑 mysqld exporter
- 应用程序也可以自己暴露 `/metrics`

这些 exporter 或应用，会提供一堆类似这样的内容：

```text
node_cpu_seconds_total{cpu="0",mode="idle"} 12345.67
node_memory_MemAvailable_bytes 8246337208
```

你不用一开始就完全看懂格式，只要知道它本质上是：

- 指标名
- 标签
- 当前值

## 第二步：Prometheus 去抓取这些指标

Prometheus 采用的是 **pull 模式**。

也就是：

- 不是客户端主动把数据推给 Prometheus
- 而是 Prometheus 自己定时去抓

例如每 15 秒抓一次：

- `http://你的主机:9100/metrics`
- `http://你的应用:8000/metrics`

这个设计的好处是：

- Prometheus 统一掌控采集节奏
- 配置和调试更直观
- 很适合内部服务网络

## 第三步：Prometheus 把数据存成时间序列

Prometheus 抓到的不是“当前状态看一眼就丢”，而是把这些值按时间存下来。

这样你后面就能查：

- 最近 5 分钟 CPU 趋势
- 过去 1 小时错误率
- 某个服务这周的请求量变化

## 第四步：查询、图表、告警

Prometheus 自己提供查询能力，也常常和 Grafana 搭配使用。

通常会是这样的组合：

- **Prometheus**：存和查指标
- **Grafana**：做图表展示
- **Alertmanager**：做告警通知

这三件事合起来，才是你平时最常见的“Prometheus 监控体系”。

## 对新手来说，先记住这几个组件就够了

如果你刚开始学，不要一口气想把全家桶全啃完。

先记这几个最核心的角色：

### 1. Prometheus
负责抓取和保存指标。

### 2. Exporter
负责把系统或服务状态暴露成 Prometheus 能读懂的指标。

最常见的是：

- `node_exporter`：监控 Linux 主机

### 3. Grafana
负责把指标画成图。

### 4. Alertmanager
负责发告警。

## 新手最适合从哪一步开始

我的建议非常明确：

> **先别急着监控一切，先学会监控一台 Linux 主机。**

这是最好的起点。

因为只要你能把下面这条链路跑通：

- Linux 主机
- node_exporter
- Prometheus
- Grafana

你对整套监控体系的理解就已经有雏形了。

## 最基础的部署思路

这里我先不讲 Kubernetes，也不讲特别复杂的生产环境。

只讲一个新手最容易理解的版本。

### 目标

你有一台 Linux 机器，想看到：

- CPU
- 内存
- 磁盘
- 网络

### 最简单的组成

- 目标主机上跑 `node_exporter`
- Prometheus 去抓它
- Grafana 读取 Prometheus 数据做展示

## 一个最小可运行的思路

### 1）启动 node_exporter

例如在 Linux 上运行：

```bash
./node_exporter
```

默认会监听：

```text
:9100
```

你打开：

```text
http://你的主机IP:9100/metrics
```

如果能看到一堆文本指标，说明第一步已经成功。

### 2）配置 Prometheus

Prometheus 的配置文件核心长这样：

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['192.168.1.100:9100']
```

意思很简单：

- 每 15 秒抓一次
- 目标是 `192.168.1.100:9100`

### 3）启动 Prometheus

启动后，你去它的 Web UI，通常是：

```text
http://你的Prometheus主机:9090
```

然后查一个指标，例如：

```text
up
```

如果返回 `1`，说明 Prometheus 已经成功抓到目标。

## 新手最常见的疑问

### Q1：为什么我打开 `/metrics` 看到的是一堆文本，不是图表？

因为 `/metrics` 本来就不是给人看的界面，它是给 Prometheus 抓取的原始数据接口。

图表应该去 Grafana 看，不是在 `/metrics` 看。

### Q2：为什么 Prometheus 查到了数据，但我还是没感觉它有什么用？

因为监控的价值通常不在“看一个瞬时值”，而在：

- 长期趋势
- 异常对比
- 告警

也就是说，单看一次查询你可能没感觉，但一旦你开始看图表和时间范围，体验会完全不一样。

### Q3：Prometheus 能不能直接替代 Zabbix？

能做的事情有重叠，但风格不完全一样。

如果你是新手，可以先这样理解：

- **Zabbix** 更偏传统、配置项很多、主机监控思路更完整
- **Prometheus** 更偏现代、时间序列核心、和云原生生态结合得更深

不一定是谁彻底替代谁，而是看你的场景。

## 新手应该怎么学 Prometheus 才不容易乱

我建议按这个顺序来：

### 第一步：理解指标是什么

至少知道：

- 指标不是日志
- 指标是数字趋势
- Prometheus 是在存时间序列

### 第二步：只监控一台 Linux 主机

先把：

- `node_exporter`
- `Prometheus`
- `Grafana`

这一条链路跑通。

### 第三步：学会查几个最基础的指标

例如：

- `up`
- `node_cpu_seconds_total`
- `node_memory_MemAvailable_bytes`
- `node_filesystem_avail_bytes`

### 第四步：再去学告警

别一开始就把自己扔进 Alertmanager 规则地狱里。

## 如果你只想先有一个正确的理解

那我会把 Prometheus 概括成这句话：

**它是现代监控系统里负责“采集指标、保存时间序列、支持查询和告警”的核心工具。**

你可以先不急着记所有组件和查询语法，但至少要理解：

- 它为什么存在
- 它和日志不同
- 它是怎么抓数据的
- 它通常和 Grafana 一起用

## 写在最后

如果你刚开始学监控，不要被 Prometheus 这个名字吓到。

它的生态确实很大，但新手真正需要跨过的第一道门槛并不高：

**先把“一台机器的指标能被采集并画成图”这件事做出来。**

只要这一步跑通了，后面再学 exporter、PromQL、告警、Kubernetes 监控，都会顺得多。

如果你现在正在入门，我会建议你下一步直接做这件事：

1. 准备一台 Linux 机器
2. 跑 `node_exporter`
3. 用 Prometheus 抓它
4. 再用 Grafana 看图

当你真的看到 CPU、内存、磁盘曲线动起来的时候，你对 Prometheus 的理解会比看十篇概念文章都快。