---
title: "Helm 是什么，应该怎么安装和使用：给 Kubernetes 新手的一篇实战入门"
urlSlug: '20260420-01'
published: 2026-04-20
description: '一篇面向新手的 Helm 入门教程：它到底解决什么问题、为什么大家在 Kubernetes 里经常用它、如何安装、怎么添加仓库、搜索 Chart、安装应用、升级、回滚和卸载。'
image: ''
tags: ['Helm', 'Kubernetes', 'k3s', 'DevOps', '教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你刚开始接触 Kubernetes，很容易在某个阶段碰到 Helm。

最常见的场景大概是这样：

- 想装 Prometheus
- 想装 Grafana
- 想装 ingress-nginx
- 别人的教程里突然冒出来一句：

```bash
helm install ...
```

这时候很多人的感觉会差不多：

**我知道这是个工具，但它到底是干什么的，我其实没真正弄明白。**

我自己一开始也是这样。

所以这篇文章我就不讲太空的概念，而是尽量按“新手真的能拿来上手”的顺序，把 Helm 讲清楚。

这篇会重点讲：

- Helm 是什么
- 为什么 Kubernetes 里经常会用到它
- 怎么安装
- 怎么添加仓库
- 怎么搜索和查看 Chart
- 怎么安装、升级、回滚、卸载

## Helm 是什么

先用一句最简单的话来说：

> **Helm 是 Kubernetes 的包管理工具。**

如果你学过 Linux，可能会更容易理解：

- `apt` 管 Debian / Ubuntu 的软件包
- `dnf` 管 Fedora 的软件包
- `pacman` 管 Arch 的软件包
- **Helm 管 Kubernetes 里的应用安装包**

这里的“包”，在 Helm 里一般叫：

- **Chart**

你可以先把它理解成：

> **别人已经把一套 Kubernetes 资源文件整理好了，你通过 Helm 可以更方便地安装、升级和管理它。**

## Helm 到底解决什么问题

如果没有 Helm，你在 Kubernetes 里装一个稍微复杂一点的应用，常常会变成这样：

- 先写 Deployment
- 再写 Service
- 再写 ConfigMap
- 再写 Secret
- 可能还要写 Ingress
- 还要考虑命名空间、资源限制、镜像版本

如果应用复杂一点，这些 YAML 文件可能有十几个甚至几十个。

这时候问题就来了：

- 手工管理很乱
- 升级不方便
- 复用不方便
- 配置环境差异时很麻烦

Helm 的思路就是把这些东西打包成一个 Chart，然后让你用类似下面的方式来装：

```bash
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

也就是说：

**你不需要手工一份份 apply 很多 YAML，而是通过 Helm 统一管理一整套资源。**

## Helm 和 kubectl 的区别是什么

这个也很容易混。

### `kubectl`
主要负责：

- 查看资源
- 创建资源
- 修改资源
- 删除资源
- 和 Kubernetes 集群交互

### `Helm`
主要负责：

- 安装一整套应用
- 管理应用版本
- 升级应用
- 回滚应用
- 复用别人打包好的 Chart

你可以这样理解：

- `kubectl` 更像是直接操作 Kubernetes
- `Helm` 更像是在 Kubernetes 之上帮你管理“应用包”

它们不是替代关系，而是经常一起用。

## Helm 里几个最常见的概念

刚开始先记住这几个就够了。

### 1. Chart
Helm 的安装包。

例如：

- `kube-prometheus-stack`
- `ingress-nginx`
- `cert-manager`

### 2. Repository
Chart 仓库。

就像软件源一样。

例如：

- `prometheus-community`
- `ingress-nginx`
- `jetstack`

### 3. Release
你通过 Helm 安装出来的实例名。

例如：

```bash
helm install monitoring prometheus-community/kube-prometheus-stack
```

这里：

- `monitoring` 是 release 名
- `prometheus-community/kube-prometheus-stack` 是 chart

也就是说：

> **Chart 是包，Release 是你装出来的实例。**

## 第一步：安装 Helm

最常见的安装方式之一是官方脚本：

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

装完以后先确认版本：

```bash
helm version
```

如果能看到版本信息，说明 Helm 已经装好了。

## 第二步：确认你的 Kubernetes 集群本身可用

Helm 不是独立工作的，它是要连 Kubernetes 集群的。

所以在正式用 Helm 之前，最好先确认：

```bash
kubectl get nodes
```

如果这一步都不通，那 Helm 后面也不会顺。

## 第三步：添加 Chart 仓库

Helm 很多时候要先加仓库，才能搜索和安装对应 Chart。

例如添加 Prometheus 社区仓库：

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
```

然后更新仓库索引：

```bash
helm repo update
```

这一步很像：

- Linux 里先加软件源
- 再刷新软件包索引

## 第四步：搜索 Chart

仓库加好以后，可以先搜一下。

例如：

```bash
helm search repo prometheus-community
```

如果只想搜某个 Chart：

```bash
helm search repo kube-prometheus-stack
```

这一步的意义在于：

- 确认仓库里确实有这个 Chart
- 看名字是不是写对了
- 顺手看看版本信息

## 第五步：查看 Chart 信息

在真的安装之前，我很建议先看看 Chart 的基本信息。

例如：

```bash
helm show chart prometheus-community/kube-prometheus-stack
```

如果想看更详细的默认配置：

```bash
helm show values prometheus-community/kube-prometheus-stack
```

这一条非常有用，因为很多时候你后面要自定义配置，第一步就是先看默认 values。

## 第六步：安装一个 Chart

先说最常见的安装结构：

```bash
helm install <release-name> <chart> -n <namespace>
```

例如安装 kube-prometheus-stack：

### 先创建命名空间

```bash
kubectl create namespace monitoring
```

### 再安装

```bash
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

这里：

- `monitoring` 是 release 名
- `prometheus-community/kube-prometheus-stack` 是 chart
- `-n monitoring` 表示装到 `monitoring` 命名空间

## 第七步：查看安装结果

装完以后不要急着觉得万事大吉，先看 Helm 自己记录的 release：

```bash
helm list -n monitoring
```

再看 Kubernetes 资源状态：

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

如果 Pod 还没起来，就继续看：

```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

## 第八步：升级一个 release

Helm 一个很大的好处就是升级比手工改很多 YAML 方便得多。

最常见的方式是：

```bash
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

如果你有自定义 values 文件，也可以这样：

```bash
helm upgrade monitoring prometheus-community/kube-prometheus-stack -n monitoring -f values.yaml
```

## 第九步：为什么很多人更常用 `upgrade --install`

因为它很方便。

```bash
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

这条命令的意思是：

- 如果没装过，就安装
- 如果已经装过，就升级

所以在自动化脚本、Ansible、CI/CD 里，这条命令非常常见。

## 第十步：查看 release 历史和回滚

如果升级以后出问题，Helm 还有一个很实用的功能：

### 查看历史版本

```bash
helm history monitoring -n monitoring
```

### 回滚到指定 revision

```bash
helm rollback monitoring 1 -n monitoring
```

这里的 `1` 是 revision 编号，具体回滚到哪一版，以 `helm history` 里看到的为准。

这也是 Helm 比“手工 apply 一堆 YAML”更省心的地方之一。

## 第十一步：卸载 release

如果想彻底删掉一个 Helm 安装出来的应用：

```bash
helm uninstall monitoring -n monitoring
```

这会删除 Helm 管理的那套 release。

然后你可以再看看资源是不是已经删掉：

```bash
kubectl get all -n monitoring
```

## 新手最常见的一些问题

### 1）命名空间不存在

比如你直接：

```bash
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

但 `monitoring` 这个 namespace 根本没创建，就会报错。

所以最稳妥的方式通常是先：

```bash
kubectl create namespace monitoring
```

### 2）Release 名和 Chart 名搞混

很多新手第一次看 Helm 命令时最容易混的是：

```bash
helm install monitoring prometheus-community/kube-prometheus-stack
```

前面那个 `monitoring` 不是 chart 名，而是你自己定义的 release 名。

### 3）仓库没加，或者没 update

如果 `helm search repo` 搜不到，很多时候不是 Chart 不存在，而是：

- 你没 `helm repo add`
- 或者加完没 `helm repo update`

### 4）集群本身没通

这个也很常见。

如果：

```bash
kubectl get nodes
```

都不正常，那 Helm 后面很多报错其实只是结果，不是根因。

### 5）值文件没看懂就乱改

很多 Chart 很强大，但默认 values 也很长。

所以我会建议新手先养成这个习惯：

```bash
helm show values <chart>
```

先看默认值，再决定要不要定制。

## 一条适合新手的实际练习路线

如果你现在只是想把 Helm 真正跑起来，我建议按这个顺序练：

### 第一步
先安装 Helm：

```bash
helm version
```

确认没问题。

### 第二步
确认 Kubernetes 集群可用：

```bash
kubectl get nodes
```

### 第三步
添加仓库：

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 第四步
搜索和查看 Chart：

```bash
helm search repo kube-prometheus-stack
helm show chart prometheus-community/kube-prometheus-stack
```

### 第五步
安装：

```bash
kubectl create namespace monitoring
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

### 第六步
查看结果：

```bash
helm list -n monitoring
kubectl get pods -n monitoring
```

只要这几步跑顺，你对 Helm 就已经不是“只会抄命令”了。

## 写在最后

如果把 Helm 的作用压缩成一句话，我觉得最容易理解的说法就是：

> **Helm 让你在 Kubernetes 里安装和管理复杂应用时，不用手工维护一大堆 YAML。**

它最值得学的地方，不是某一条命令，而是：

- 你开始把一整套 Kubernetes 资源当作“应用包”来管理
- 你可以更方便地安装、升级、回滚和卸载

对新手来说，我觉得最好的入门方式不是一上来就研究 Helm Chart 开发，而是：

- 先装起来
- 先会加 repo
- 先会 search
- 先会 show values
- 先会 install / upgrade / rollback / uninstall

只要这条链路走顺了，后面你再看别人教程里的 `helm install`，就不会只剩“我跟着敲”这种感觉了。