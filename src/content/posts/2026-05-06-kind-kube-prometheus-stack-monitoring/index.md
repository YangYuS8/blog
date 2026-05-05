---
title: "如何在 kind 中部署 kube-prometheus-stack：用 Helm 搭一套可访问的 Grafana、Prometheus 和 Alertmanager 练习环境"
urlSlug: '20260506-01'
published: 2026-05-06
description: '一篇按步骤展开的 kind 监控实战教程：创建多节点集群、安装 ingress-nginx、部署 kube-prometheus-stack、配置 Grafana/Prometheus/Alertmanager 访问入口，并用 ServiceMonitor 接入一个示例应用。'
image: ''
tags: ['kind', 'Kubernetes', 'Helm', 'Prometheus', 'Grafana', 'Alertmanager', '教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你已经把 `kind` 装好了，接下来很适合练的一套内容，就是在本地 Kubernetes 里把完整监控栈搭起来。

这篇文章讲的不是只把 Grafana 页面打开，而是按一条更接近真实集群运维的路线，完成下面这套环境：

- `kind` 多节点集群
- `ingress-nginx`
- `kube-prometheus-stack`
- `Grafana / Prometheus / Alertmanager` 的 Ingress 访问
- `ServiceMonitor` 自动发现自定义应用指标

整套操作做完以后，你会同时理解两件事：

1. **怎么把监控栈部署起来**
2. **为什么 Prometheus Operator 体系比手写 `scrape_config` 更适合 Kubernetes**

## 这套方案到底在做什么

先用最短的话解释一下。

`kube-prometheus-stack` 不是单独装一个 Prometheus。

它本质上是一个基于 **Prometheus Operator** 的 Kubernetes 监控方案，通常会把这些组件一起部署出来：

- Prometheus：采集和存储指标
- Grafana：看图表和 Dashboard
- Alertmanager：处理告警
- node-exporter：采集节点指标
- kube-state-metrics：采集 Kubernetes 对象状态指标
- Prometheus Operator：用 Kubernetes CRD 管理监控配置

它和“手工装一个 Prometheus + 自己写一堆抓取规则”的区别在于：

- 你不再主要依赖手写 `scrape_config`
- 而是通过 `ServiceMonitor`、`PodMonitor`、`PrometheusRule` 这些 Kubernetes 资源管理监控

这就是为什么它更适合拿来练 Kubernetes 监控。

## 你需要提前准备什么

本文默认你本机已经有这些工具：

- `kind`
- `kubectl`
- `helm`
- 一个能正常运行的 Docker / 容器运行环境

你可以先简单确认一下：

```bash
kind version
kubectl version --client
helm version
```

如果这三条命令都能正常输出版本，再继续往下做。

## 第一步：创建一个专门练监控的 kind 多节点集群

先单独建一个集群，不要和之前的实验环境混在一起。

新建配置文件：

```bash
cat > kind-observability.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30080
        hostPort: 8080
        protocol: TCP
      - containerPort: 30443
        hostPort: 8443
        protocol: TCP
  - role: worker
  - role: worker
EOF
```

创建集群：

```bash
kind create cluster --name obs --config kind-observability.yaml
kubectl get nodes -o wide
```

### 这一步的作用是什么

这里最关键的是 `extraPortMappings`。

它把宿主机端口映射到了 kind 控制平面节点里：

- `localhost:8080 -> kind control-plane:30080`
- `localhost:8443 -> kind control-plane:30443`

后面我们会把 `ingress-nginx` 的 `NodePort` 固定到 `30080` 和 `30443`，这样你就能直接从浏览器访问：

- Grafana
- Prometheus
- Alertmanager

如果不提前做这个端口映射，后面的 Ingress 虽然资源能创建成功，但你从宿主机访问会不方便很多。

## 第二步：安装 ingress-nginx

先加仓库并更新索引：

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

安装 `ingress-nginx`：

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --wait
```

检查结果：

```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

### 这一步的作用是什么

`ingress-nginx` 是这套实验里的统一入口。

它的作用可以直接理解成：

- 根据域名把请求转发到不同服务
- 让 Grafana、Prometheus、Alertmanager 都能通过浏览器访问

这里把 Service 类型设成 `NodePort`，并且固定端口为：

- HTTP: `30080`
- HTTPS: `30443`

配合上一步的 kind 端口映射，宿主机访问 `8080/8443` 就能进集群里的 Ingress。

## 第三步：给本地域名做 hosts 映射

把这几个域名加到本机 `/etc/hosts`：

```bash
echo "127.0.0.1 grafana.local prometheus.local alertmanager.local" | sudo tee -a /etc/hosts
```

后面访问地址就是：

- `http://grafana.local:8080`
- `http://prometheus.local:8080`
- `http://alertmanager.local:8080`

### 这一步的作用是什么

Ingress 主要是按 `Host` 匹配规则转发流量。

所以这里不是随便写三个名字，而是让浏览器访问时真正带上：

- `grafana.local`
- `prometheus.local`
- `alertmanager.local`

如果你只访问 `http://127.0.0.1:8080`，Ingress 往往无法按你期望的规则把请求转到目标服务。

## 第四步：写 kube-prometheus-stack 的 values 文件

新建一个自定义 values 文件：

```bash
cat > kube-prometheus-stack-values.yaml <<'EOF'
fullnameOverride: kps

grafana:
  enabled: true
  adminPassword: admin
  defaultDashboardsTimezone: browser
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.local
    path: /

prometheus:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - prometheus.local
    paths:
      - /
  prometheusSpec:
    retention: 2d
    scrapeInterval: 15s
    evaluationInterval: 15s

    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

    serviceMonitorNamespaceSelector: {}
    podMonitorNamespaceSelector: {}
    ruleNamespaceSelector: {}

    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        memory: 2Gi

alertmanager:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - alertmanager.local
    paths:
      - /
  alertmanagerSpec:
    retention: 120h

kubeControllerManager:
  enabled: false

kubeScheduler:
  enabled: false

kubeEtcd:
  enabled: false
EOF
```

### 这一步的作用是什么

这个文件是整篇里最重要的一步之一。

因为它不只是“改几个参数”，而是在明确这套监控栈的行为。

下面分几块看。

### 1. 打开 Grafana / Prometheus / Alertmanager 的 Ingress

这三段配置的作用是：

- 给 Grafana 配 `grafana.local`
- 给 Prometheus 配 `prometheus.local`
- 给 Alertmanager 配 `alertmanager.local`

这样安装完以后，你就能直接用浏览器访问它们。

### 2. 设置 Prometheus 的保留时间和采集频率

```yaml
retention: 2d
scrapeInterval: 15s
evaluationInterval: 15s
```

这里的含义分别是：

- `retention: 2d`：指标保留 2 天
- `scrapeInterval: 15s`：每 15 秒抓一次指标
- `evaluationInterval: 15s`：每 15 秒执行一次规则计算

对于本地 kind 实验环境，这样的设置够用，也不会把资源拉得太高。

### 3. 允许跨命名空间发现监控对象

```yaml
serviceMonitorSelectorNilUsesHelmValues: false
podMonitorSelectorNilUsesHelmValues: false
ruleSelectorNilUsesHelmValues: false

serviceMonitorNamespaceSelector: {}
podMonitorNamespaceSelector: {}
ruleNamespaceSelector: {}
```

这一组配置很关键。

它的实际效果是让 Prometheus 不只盯着 `monitoring` 命名空间里的对象，而是可以发现整个集群中的：

- `ServiceMonitor`
- `PodMonitor`
- `PrometheusRule`

这也是后面你在 `demo` 命名空间创建 `ServiceMonitor` 时，Prometheus 仍然能自动识别它的原因。

### 4. 限制 Prometheus 资源占用

```yaml
resources:
  requests:
    cpu: 200m
    memory: 512Mi
  limits:
    memory: 2Gi
```

因为 kind 是本地实验集群，不像正式生产环境那样资源充足。

这段配置的作用是：

- 给 Prometheus 一个基础资源请求值
- 避免它在本地机器上无限吃内存

### 5. 关闭 kind 里常见的控制平面红色 Target

```yaml
kubeControllerManager:
  enabled: false

kubeScheduler:
  enabled: false

kubeEtcd:
  enabled: false
```

这是很实用的一组开关。

在很多本地 kind 环境里，这些控制平面组件的指标暴露方式和真实集群不完全一样，直接打开后，Prometheus Targets 页面可能会出现一堆 `Down`。

先关掉它们的作用是：

- 降低初学时的噪音
- 让你先把主要监控链路跑通
- 避免一上来就被一堆红色状态误导

## 第五步：安装 kube-prometheus-stack

先加仓库并更新：

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

创建命名空间并安装：

```bash
kubectl create namespace monitoring

helm upgrade --install kps prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f kube-prometheus-stack-values.yaml \
  --wait \
  --timeout 10m
```

安装完成后检查：

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
kubectl get ingress -n monitoring
kubectl get prometheus -n monitoring
kubectl get alertmanager -n monitoring
kubectl get servicemonitors -A
```

### 这一步的作用是什么

这一步会把整套监控栈真正装进集群。

常见会被创建出来的内容包括：

- Grafana
- Prometheus Operator
- Prometheus 实例
- Alertmanager 实例
- kube-state-metrics
- node-exporter
- 一组默认规则和 Dashboard 配置

你在这里第一次看到的重点，不应该只是 Pod `Running`，还应该注意：

- 有没有创建 `Ingress`
- 有没有创建 `Prometheus` 自定义资源
- 有没有创建一批 `ServiceMonitor`

这些资源恰恰体现了它是 **Prometheus Operator 体系**，而不是传统的“装一个 Deployment 就完了”。

## 第六步：访问 Grafana、Prometheus 和 Alertmanager

浏览器访问：

- `http://grafana.local:8080`
- `http://prometheus.local:8080`
- `http://alertmanager.local:8080`

Grafana 默认登录信息：

```text
用户名：admin
密码：admin
```

### 这一步你应该看到什么

如果前面的部署都正常，Grafana 里通常已经会有不少 Kubernetes 相关 Dashboard。

比如：

- `Kubernetes / Compute Resources / Cluster`
- `Kubernetes / Compute Resources / Namespace`
- `Kubernetes / Compute Resources / Pod`
- `Node Exporter / Nodes`

这说明这套监控栈不只是“服务起来了”，而是：

- Prometheus 已经在采集数据
- Grafana 已经配置好了数据源
- 默认 Dashboard 已经能直接展示 Kubernetes 指标

## 第七步：部署一个带 metrics 的示例应用

真正能说明你已经理解这套体系的，不是把 Grafana 打开，而是把自己的应用接进来。

先创建命名空间：

```bash
kubectl create namespace demo
```

再写示例应用清单：

```bash
cat > demo-app.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus-example-app
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: prometheus-example-app
  template:
    metadata:
      labels:
        app: prometheus-example-app
    spec:
      containers:
        - name: app
          image: quay.io/brancz/prometheus-example-app:v0.5.0
          ports:
            - name: web
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-example-app
  namespace: demo
  labels:
    app: prometheus-example-app
spec:
  selector:
    app: prometheus-example-app
  ports:
    - name: web
      port: 8080
      targetPort: web
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prometheus-example-app
  namespace: demo
spec:
  selector:
    matchLabels:
      app: prometheus-example-app
  endpoints:
    - port: web
      path: /metrics
      interval: 15s
EOF
```

应用清单：

```bash
kubectl apply -f demo-app.yaml
```

检查结果：

```bash
kubectl get pods -n demo
kubectl get svc -n demo
kubectl get servicemonitor -n demo
```

### 这一步的作用是什么

这份 YAML 一共做了三件事：

### 1. 部署应用

`Deployment` 会创建两个副本的示例应用 Pod。

### 2. 暴露应用

`Service` 把这些 Pod 统一暴露成一个稳定的服务入口。

### 3. 告诉 Prometheus 应该怎么抓它

`ServiceMonitor` 才是这里的重点。

它不是直接写采集规则到 Prometheus 配置文件里，而是用 Kubernetes 资源声明：

- 匹配哪些 Service
- 抓哪个端口
- 抓哪个路径
- 多久抓一次

也就是说，**ServiceMonitor 是 Prometheus Operator 世界里的“监控接入声明”**。

只要 Prometheus 被配置成允许发现这个命名空间里的 `ServiceMonitor`，它就会自动把这个应用加入抓取目标。

## 第八步：去 Prometheus 页面验证 Target 和指标

打开：

- `http://prometheus.local:8080`

然后进入：

- `Status -> Targets`

如果配置正确，你应该能看到和 `demo/prometheus-example-app` 相关的 Target。

再试两个简单查询：

```text
version
```

```text
http_requests_total
```

### 这一步的作用是什么

这一步是在验证整条链路是否真的跑通：

- 应用是否正常暴露 `/metrics`
- Service 是否正确指向 Pod
- ServiceMonitor 是否正确匹配到 Service
- Prometheus 是否真的发现并抓到了这个目标

如果这里能看到 Target `Up`，说明你已经完成了从“部署监控栈”到“接入自定义应用”的闭环。

## 第九步：这套环境起来以后，应该重点练什么

环境搭好以后，不要只停留在“我会访问 Grafana”。

更值得练的是下面这些内容：

1. Grafana Dashboard 是怎么自动出现的
2. Prometheus 的 Targets 为什么会 `Up` 或 `Down`
3. `ServiceMonitor` 是怎么发现 `Service` 的
4. `kube-state-metrics` 到底提供了哪些 Kubernetes 对象指标
5. `node-exporter` 到底提供了哪些节点指标
6. `PrometheusRule` 应该怎么写
7. `Alertmanager` 怎么接收和分组告警
8. Helm values 是怎么覆盖默认 chart 配置的

可以重点看这些命令：

```bash
kubectl get servicemonitors -A
kubectl describe servicemonitor -n demo prometheus-example-app

kubectl get prometheusrules -A
kubectl get pods -n monitoring
kubectl logs -n monitoring deploy/kps-operator

kubectl get secret -n monitoring
kubectl get cm -n monitoring | grep grafana
```

## 常见问题 1：为什么我要先装 ingress-nginx

因为这篇的目标不只是把监控栈“装进去”，还包括让你能从浏览器稳定访问多个服务。

如果没有 Ingress，你当然也可以：

- 用 `kubectl port-forward`
- 或者改成 `NodePort`

但那样每个服务都要单独处理，体验不统一，也不利于理解 Kubernetes 中的入口流量管理。

## 常见问题 2：为什么 values 里要关闭 controller-manager、scheduler、etcd

不是因为它们不重要，而是因为在本地 kind 环境里，它们经常会带来不必要的 `Down` Target 噪音。

先关掉的目的是：

- 让主流程先跑通
- 让你先把注意力放在应用接入和监控链路上
- 后面如果你要继续深挖控制平面监控，再单独打开排查

## 常见问题 3：为什么要单独写 ServiceMonitor

因为这是 Prometheus Operator 的核心使用方式。

传统 Prometheus 更偏向：

- 手工维护抓取配置

而在 Kubernetes 里，更自然的方式是：

- 让监控配置也变成 Kubernetes 资源
- 让应用通过标签和资源声明被自动发现

这就是 `ServiceMonitor` 的价值。

## 清理环境

如果你练完了，想一键清理，可以按下面做。

先删监控栈：

```bash
helm uninstall kps -n monitoring
kubectl delete namespace monitoring
```

如果你还想彻底删掉 Operator 相关 CRD，可以继续：

```bash
kubectl delete crd alertmanagerconfigs.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com
kubectl delete crd podmonitors.monitoring.coreos.com
kubectl delete crd probes.monitoring.coreos.com
kubectl delete crd prometheusagents.monitoring.coreos.com
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd prometheusrules.monitoring.coreos.com
kubectl delete crd scrapeconfigs.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd thanosrulers.monitoring.coreos.com
```

最后删除整个 kind 集群：

```bash
kind delete cluster --name obs
```

## 这篇流程做完以后，你真正掌握了什么

如果你把上面这一套完整跑通，收获不只是“会装一个监控组件”。

更准确地说，你已经练到了这些内容：

- 会在 kind 里搭一个可访问的监控实验环境
- 知道 `ingress-nginx` 在这里承担什么角色
- 知道 `kube-prometheus-stack` 为什么比单独装 Prometheus 更适合 Kubernetes
- 知道 `ServiceMonitor` 是怎么把应用接进 Prometheus 的
- 知道如何验证 Target、指标和 Dashboard 是否真的生效

如果你后面继续深入这套环境，可以把练习重点放在这些方向：

- 调整 `ServiceMonitor` 和 `PodMonitor` 的发现范围
- 自己写一条 `PrometheusRule` 做告警实验
- 给 Alertmanager 配一个真实的告警接收方式
- 观察某个应用从暴露指标到进入 Dashboard 的完整链路

这样再回头看这篇流程时，你就不只是“照着装完一套环境”，而是真的把 Kubernetes 监控体系从部署、发现到验证完整走了一遍。