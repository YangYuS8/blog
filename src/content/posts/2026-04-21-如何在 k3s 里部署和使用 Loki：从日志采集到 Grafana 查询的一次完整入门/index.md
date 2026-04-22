---
title: "如何在 k3s 里部署和使用 Loki：按官方当前推荐路线完成一次最小可用实践"
urlSlug: '20260421-02'
published: 2026-04-21
description: '基于 Grafana 官方当前路线，在单机 k3s 中用 Helm 部署 Loki，并用 Grafana Alloy 代替已停止更新的 Promtail 完成日志采集，最后在 Grafana 中查询 Pod 日志。'
image: ''
tags: ['Loki', 'Grafana', 'Grafana Alloy', 'Kubernetes', 'k3s', '日志', 'Helm', '实战']
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

这次直接按 `k3s` 实战来讲 Loki，不再绕概念。

目标很明确：

- 在单机 `k3s` 里部署 `Loki`
- 用官方当前更推荐的 `Grafana Alloy` 做日志采集
- 把 Pod 日志送进 Loki
- 最后在 `Grafana` 里查到日志

这篇用的是目前更贴近官方文档的思路，而不是继续用已经逐步退出主线的 `Promtail`。

## 一、先说这次为什么不用 Promtail

这里先把路线定清楚。

过去提到 Loki，很多教程都会直接写：

- Loki
- Promtail
- Grafana

这条路以前没问题，但现在如果按更接近官方当前推荐的方向走，应该优先看：

- **Loki** 作为日志后端
- **Grafana Alloy** 作为采集代理
- **Grafana** 作为查询界面

原因很简单：

> **Promtail 已经不再是后续重点发展的采集路线，新的采集能力主要往 Grafana Alloy 上收。**

所以这次我直接按 Alloy 来做，不再沿用旧教程思路。

## 二、这次要落的最小结构

这次结构很简单：

```text
Pod 日志
  ↓
Grafana Alloy
  ↓
Loki
  ↓
Grafana
```

为了控制复杂度，这次先只做最小可用方案：

- `Loki`：单实例
- `Grafana Alloy`：负责采集容器日志
- `Grafana`：直接接入 Loki 数据源查询日志

这次不先追：

- 多副本高可用
- 对象存储后端
- 分布式 Loki
- 特别复杂的日志处理

先把一条可用链路打通。

## 三、准备工作

先确保这几个前提已经成立：

### 1. k3s 集群正常

```bash
kubectl get nodes
kubectl get pods -A
```

### 2. Helm 可用

```bash
helm version
```

### 3. 你已经有一个可用的 Grafana

如果你前面已经装过 `kube-prometheus-stack`，那通常已经有 Grafana，可以直接复用。

例如先看一下：

```bash
kubectl get svc -n monitoring
```

只要 Grafana 还在，就不用重复装一个新的。

## 四、添加 Helm 仓库

这次至少要用到 Grafana 的 chart 仓库。

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

如果你后面还要对照 chart 参数，最好顺手看一下默认 values：

```bash
helm show values grafana/loki > loki-default-values.yaml
helm show values grafana/alloy > alloy-default-values.yaml
```

这个动作很值，因为后面要改配置时，不至于完全盲写。

## 五、先部署 Loki

### 1. 创建命名空间

我这里统一放到 `logging`：

```bash
kubectl create namespace logging
```

### 2. 写一个最小可用的 Loki values

新建 `loki-values.yaml`：

```yaml
deploymentMode: SingleBinary

singleBinary:
  replicas: 1

loki:
  auth_enabled: false

  commonConfig:
    replication_factor: 1

  storage:
    type: filesystem

  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h

  limits_config:
    allow_structured_metadata: true
    volume_enabled: true

chunksCache:
  enabled: false
resultsCache:
  enabled: false

backend:
  replicas: 0
read:
  replicas: 0
write:
  replicas: 0

ingester:
  replicas: 0
querier:
  replicas: 0
queryFrontend:
  replicas: 0
queryScheduler:
  replicas: 0
indexGateway:
  replicas: 0
compactor:
  replicas: 0
ruler:
  replicas: 0

minio:
  enabled: false

gateway:
  enabled: false
```

这个写法的目的很明确：

- 强制单机最小模式
- 走本地文件存储
- 不启用分布式那一堆组件
- 先把学习成本压下来

### 3. 安装 Loki

```bash
helm install loki grafana/loki -n logging -f loki-values.yaml
```

### 4. 验证 Loki

```bash
kubectl get pods -n logging
kubectl get svc -n logging
```

你至少要看到 Loki 相关 Pod 正常起来。

## 六、再部署 Grafana Alloy

这一步才真正把日志采集链路接上。

### 1. 写 Alloy values

新建 `alloy-values.yaml`：

```yaml
alloy:
  configMap:
    create: true
    content: |-
      logging {
        level  = "info"
        format = "logfmt"
      }

      discovery.kubernetes "pods" {
        role = "pod"
      }

      discovery.relabel "pod_logs" {
        targets = discovery.kubernetes.pods.targets

        rule {
          source_labels = ["__meta_kubernetes_namespace"]
          target_label  = "namespace"
        }

        rule {
          source_labels = ["__meta_kubernetes_pod_name"]
          target_label  = "pod"
        }

        rule {
          source_labels = ["__meta_kubernetes_pod_container_name"]
          target_label  = "container"
        }

        rule {
          source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
          target_label  = "app"
        }
      }

      loki.source.kubernetes "pod_logs" {
        targets    = discovery.relabel.pod_logs.output
        forward_to = [loki.write.default.receiver]
      }

      loki.write "default" {
        endpoint {
          url = "http://loki.logging.svc.cluster.local:3100/loki/api/v1/push"
        }
      }

controller:
  type: daemonset

serviceMonitor:
  enabled: false
```

这里最关键的点有两个：

### 第一，采集方式是 DaemonSet

因为它本来就应该按节点采集容器日志。

### 第二，日志是直接发给集群内 Loki Service

也就是：

```text
http://loki.logging.svc.cluster.local:3100/loki/api/v1/push
```

### 2. 安装 Alloy

```bash
helm install alloy grafana/alloy -n logging -f alloy-values.yaml
```

### 3. 验证 Alloy

```bash
kubectl get pods -n logging
```

如果正常，你应该能看到 Alloy 以 DaemonSet 方式运行。

## 七、确认日志确实进入 Loki

不要只停在“Pod 是 Running”。

这一步一定要验证。

### 1. 查看 Alloy 日志

```bash
kubectl logs -n logging -l app.kubernetes.io/name=alloy --tail=100
```

如果采集和推送有问题，这里通常会有明显报错。

这里最常见的一个问题，就是还在沿用手工拼 `/var/log/pods` 的旧规则，结果 Alloy 虽然是 Running，但一直在报 `stat ... no such file or directory`。

如果是在 k3s 这种环境里，我现在更建议直接改用 `loki.source.kubernetes`，避免自己去猜节点上的日志目录结构。

### 2. 先制造一点业务日志

最简单的方法是起一个会不断输出日志的小 Pod。

例如：

```bash
kubectl create deployment logtest --image=busybox -- sleep 3600
kubectl exec deploy/logtest -- sh -c 'while true; do echo "hello from logtest"; sleep 5; done' &
```

如果你不想这么折腾，也可以直接看现有应用的日志采集情况。

重点是：

> **要让 Loki 有东西可查。**

## 八、在 Grafana 里接入 Loki

如果你已经有 Grafana，这一步最实际。

### 1. 打开 Grafana

进入：

- Connections
- Data sources
- Add data source
- 选择 Loki

### 2. 填 Loki 地址

在集群内常见的地址就是：

```text
http://loki.logging.svc.cluster.local:3100
```

如果 Grafana 和 Loki 都在同一个集群里，这个地址通常就够用。

### 3. 保存并测试

如果 Grafana 能连上 Loki，就说明：

- 数据源配置没问题
- Loki 服务本身可访问

## 九、在 Grafana 里查日志

这一步才是这次部署真正的验收。

进入 Grafana 的 Explore 页面，选择 Loki 数据源。

最先可以试的查询思路是：

### 按 namespace 查

```text
{namespace="default"}
```

### 按 pod 查

```text
{pod="logtest-xxxxxx-xxxxx"}
```

### 按 container 查

```text
{container="logtest"}
```

如果前面 Alloy 配置和 Loki 都没问题，这里就应该能看到日志。

## 十、这次部署里最关键的几个点

### 1. Loki 先走单机最小模式

别一上来就追分布式。

### 2. 采集器直接用官方当前主线的 Alloy

不要继续把重点压在旧 Promtail 路线上。

### 3. Alloy 重点不是“装上”，而是配置对

最关键的是：

- 能发现 Pod
- 能映射到节点日志路径
- 能附上常用标签
- 能把日志推到 Loki

### 4. Grafana 里能查到日志，才算结束

不是 Pod 全绿就算成功。

## 十一、这条路线最容易踩的坑

### 1. Loki 起了，但 Alloy 没采到日志

这通常不是 Loki 本身坏了，而是：

- 日志路径规则没对上
- Kubernetes 发现规则没对上
- 标签重写规则有问题

### 2. Alloy 起了，但推不到 Loki

这时候通常要先看：

- Loki Service 地址写得对不对
- Namespace 对不对
- 集群内 DNS 是否正常

### 3. Grafana 配了 Loki，但 Explore 里没数据

这时候别先怪 Grafana。

先回头查：

- Loki 里到底有没有数据
- Alloy 有没有报错
- 业务日志到底有没有产生

## 十二、这次实战的最小成功标准

这次我会把“成功”定义得很明确：

- Loki Running
- Alloy Running
- Grafana 数据源正常
- Explore 页面能查到真实 Pod 日志

只要这四条都成立，这次 Loki 路线就算真正跑通。

## 写在最后

如果目标是单机 `k3s` 学习环境，我会更推荐把 Loki 这条路线理解成：

> **先用 Loki 做后端，用 Alloy 做采集，用 Grafana 做查询，先把一条最小可用日志链路跑通。**

这条链路一旦通了，后面再继续补：

- 更复杂的标签设计
- 更多日志来源
- retention 策略
- 更完整的 Grafana 仪表盘

都会顺很多。