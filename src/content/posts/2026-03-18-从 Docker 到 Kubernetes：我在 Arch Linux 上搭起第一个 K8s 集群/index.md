---
title: "Kubernetes 第一课：在 EndeavourOS 上搭建本地集群并完成第一次部署排障"
urlSlug: '20260318-01'
published: 2026-03-18
description: '记录我在 EndeavourOS 上学习 Kubernetes 的第一课：从 kind 建集群、Deployment 部署 nginx，到排查镜像拉取失败、修正 Service 端口映射、扩容、滚动更新与回滚。'
image: ''
tags: ['kubernetes', 'k8s', 'docker', 'kind', 'kubectl', 'endeavouros', 'archlinux']
category: '云原生'
draft: false 
lang: 'zh_CN'
---

这篇文章是我学习 Kubernetes 的第一课总结。和“只会背概念”不同，这次我直接在自己的电脑上动手，把一个本地 K8s 集群从 0 跑起来，然后真的踩了一轮坑：镜像拉取失败、Service 端口映射错误、滚动更新卡住，最后再把故障版本回滚回去。

我的目标不是先把所有概念背熟，而是先建立一条最基本的实战链路：**建集群 → 部署应用 → 暴露服务 → 排障 → 扩容 → 更新 → 回滚**。

## 我的环境

这次实验环境就是我自己的日常开发机：

- 系统：EndeavourOS（Arch 系）
- 内核：Linux 6.19.8
- CPU：i7-12700H
- 内存：31GB
- 容器环境：Docker 已安装并可用

这个环境的好处很明显：本地试错成本低，出问题可以随时删掉重来，也方便我把 Docker 里已经熟悉的一些概念迁移到 Kubernetes。

## 为什么第一课不直接上 kubeadm

如果是第一次系统学 K8s，我现在不建议自己一开始就上 `kubeadm`。原因很简单：`kubeadm` 更适合理解集群安装、控制平面、证书、节点加入这些更底层的内容，而我这一阶段更需要的是先跑通“如何部署一个应用”。

所以第一课我选的是：

- 用 Docker 做底层容器运行环境
- 用 `kind` 起本地 Kubernetes 集群
- 用 `kubectl` 管理集群

这个思路和学 Docker 很像：先学会把容器跑起来，再去研究更底层的实现细节。

## 用 Docker 的视角理解 K8s 的前三个核心对象

为了不一开始陷进一堆名词，我先用 Docker 做类比：

- `docker run` 对应的是 **Pod / Deployment**
- `docker ps` 对应的是 `kubectl get pods`
- `docker logs` 对应的是 `kubectl logs`
- `docker exec -it` 对应的是 `kubectl exec -it`

但 Kubernetes 比 Docker 多出来的一层核心能力，是**编排**。

我在第一课里接触到的 3 个核心对象可以先这样理解：

### Pod
Pod 是真正运行容器的地方。它可以先类比成“一个被 K8s 托管的容器运行单元”。

### Deployment
Deployment 不是直接跑业务，而是负责描述：

- 我要跑哪个镜像
- 我想要几个副本
- 更新时怎么替换旧 Pod

如果硬要做类比，它更像是 Docker 世界里“运行策略 + 副本管理 + 更新策略”的组合。

### Service
Service 负责给一组 Pod 提供一个稳定入口。Pod 的 IP 不是固定资产，但 Service 的名字和访问方式是稳定的。

这也是我第一课里最深的感受之一：**Deployment 管 Pod 的生命周期，Service 管 Pod 的访问入口。**

## 第一步：检查宿主机环境

开始前我先确认了宿主机的 Docker 状态。结果很明确：

- Docker 没问题
- Docker daemon 在正常运行
- 但 `kind` 和 `kubectl` 没装

这个检查很值，因为它让我先把问题边界划清楚。K8s 的很多问题，根本不一定是 Kubernetes 自身的问题。如果宿主机的容器环境就没准备好，后面的现象会非常乱。

## 第二步：安装 kubectl 和 kind，创建本地集群

安装完 `kubectl` 和 `kind` 之后，我创建了第一个集群：

```bash
kind create cluster --name lab
kubectl cluster-info --context kind-lab
kubectl get nodes
```

看到节点 `Ready` 的那一刻，Kubernetes 对我来说就不再只是抽象名词，而是变成了一个真的能在本地操作和观察的系统。

## 第三步：部署第一个应用，第一次遇到 ErrImagePull

我接着部署了 nginx：

```bash
kubectl create deployment nginx --image=nginx
kubectl get deployments
kubectl get pods -o wide
```

结果 Deployment 创建成功了，但 Pod 没有进入 `Running`，而是卡在：

```text
ErrImagePull
ImagePullBackOff
```

这一步很关键，因为它让我第一次意识到：

**Deployment 创建成功，不等于业务已经跑起来。**

Deployment 成功，只能说明“期望状态被提交到了 K8s”；Pod 能不能真的跑起来，还要看调度、镜像、网络、容器启动这些后续环节。

## 第四步：第一次排障，不是 YAML 写错，而是镜像拉取链路有问题

我没有继续猜，而是先看 Pod 事件：

```bash
kubectl describe pod <pod-name>
```

然后在 `Events` 里看到真正的报错是：

- 拉取 `docker.io/library/nginx:latest` 超时
- 访问 Docker Hub 的认证和镜像服务失败

这一步非常重要，因为它说明：

- 调度已经成功
- Deployment 逻辑没有明显问题
- 真正失败的是**容器运行时拉镜像**

于是我继续在宿主机执行：

```bash
docker pull nginx
```

结果宿主机也失败了。到这里问题就非常清楚了：

**不是 K8s 不会部署 nginx，而是我当前机器到 Docker Hub 的链路本身就不通。**

继续检查后，我确认了这些事实：

- 我本机使用了本地代理 `127.0.0.1:7890`
- 直连 `auth.docker.io` 和 `registry-1.docker.io` 都不通
- 代理对某些仓库可用，但对 Docker Hub 的认证链路不稳定

这一步让我第一次真正体会到运维排障的思路：

> 遇到 `ErrImagePull`，先不要怪 K8s。先区分是资源对象写错了，还是网络、代理、仓库可达性出了问题。

## 第五步：换镜像仓库继续推进，而不是卡死在 Docker Hub

既然 Docker Hub 这条链路不稳定，那最实际的做法不是硬耗，而是换一个当前能拉通的镜像仓库。

我后面验证发现这两个镜像可以在宿主机成功拉取：

```bash
docker pull registry.k8s.io/pause:3.10
docker pull quay.io/nginx/nginx-unprivileged:stable
```

所以我把 Deployment 的镜像更新成了：

```bash
kubectl set image deployment/nginx nginx=quay.io/nginx/nginx-unprivileged:stable
```

然后新 Pod 成功启动，旧的失败 Pod 被逐步替换掉。

这一步让我开始理解滚动更新的实际表现：

- 我改的是 Deployment
- K8s 创建了新的 Pod
- 新 Pod 成功后，旧 Pod 被终止

也就是说，**Deployment 是声明“我要什么”，Pod 是它实际生成出来的运行结果。**

## 第六步：Service 能创建，不代表流量一定能转发正确

Pod 跑起来之后，我继续创建 Service：

```bash
kubectl expose deployment nginx --port=80 --type=ClusterIP
kubectl get svc
kubectl port-forward svc/nginx 8080:80
```

但浏览器打不开页面。

这时候我的第一反应是：是不是 Service 拒绝连接？后来排查才发现，真正的问题是**端口映射不对**。

因为我现在用的是 `nginx-unprivileged`，容器实际监听的是 `8080`，但我最初的 Service 默认转发到了 `80`。于是出现了这样一种很典型的 K8s 故障：

- Pod 是 Running
- Service 也存在
- 但流量转发到了错误端口

我后面的验证方式非常直接：

### 先直接连 Pod

```bash
kubectl port-forward pod/<pod-name> 8080:8080
```

如果这个能访问，说明 Pod 内的 nginx 没问题。

### 再修正 Service

```bash
kubectl delete svc nginx
kubectl expose deployment nginx --port=80 --target-port=8080 --type=ClusterIP
kubectl port-forward svc/nginx 8080:80
```

修正后，页面可以正常打开。

这一步给了我一个非常重要的排障方法：

- **Pod 能通，Service 不通**：优先查 selector 和 targetPort
- **Pod 也不通**：优先查容器本身有没有正常监听、应用有没有真正启动

## 第七步：扩容到 3 个副本，第一次真正理解 Service 面向的是一组 Pod

服务正常访问之后，我做了扩容：

```bash
kubectl scale deployment nginx --replicas=3
kubectl get pods -o wide
kubectl get endpoints nginx
```

扩容后我看到了 3 个 Running Pod，也看到了 `endpoints` 里挂了 3 个后端地址。

这时我才真正把一句很常见的话理解透：

**Service 面向的是一组 Pod，而不是某一个固定 Pod。**

这句话的实际含义是：

- 某个 Pod 坏了，Service 还可以把流量发给其他 Pod
- 扩容时，Service 会自动感知新的后端
- 更新时，旧 Pod 和新 Pod 可以逐步交接，客户端不需要感知后端名字变化

如果用 Docker 来类比，Service 更像是一个稳定入口，而不是你手动盯着某个具体容器的 IP 去访问。

## 第八步：故意触发一次滚动更新失败，再做回滚

为了继续理解 Deployment，我又故意做了一次镜像更新：

```bash
kubectl set image deployment/nginx nginx=registry.k8s.io/pause:3.10
kubectl rollout status deployment/nginx
kubectl get pods -w
kubectl rollout history deployment/nginx
```

这次更新没有成功。新 Pod 一直处于 `ImagePullBackOff`，`rollout status` 也一直卡住。

我继续看新 Pod 的事件，发现 kind 节点容器里的镜像拉取链路依旧不稳定。

但这次最大的收获不是“又遇到了网络问题”，而是我看到了 **滚动更新失败时，旧 Pod 并没有被一把删光**。

也就是说，Deployment 的更新逻辑不是：

- 先全删旧 Pod
- 再赌新 Pod 能不能起来

而是：

- 先尝试创建新 Pod
- 新 Pod Ready 后再逐步删除旧 Pod
- 如果新版本有问题，旧版本仍然尽量保留

这也解释了为什么 K8s 适合在线服务：它的默认思路不是“尽快替换完”，而是“尽量保证服务可用”。

最后我执行了回滚：

```bash
kubectl rollout undo deployment/nginx
kubectl rollout status deployment/nginx
kubectl get pods -o wide
```

回滚成功后，Deployment 恢复到了之前可用的 nginx 版本，最终重新回到了 3 个 Running Pod 的状态。

## 这一课我真正学到的，不只是命令

如果只看命令，今天我学到的是这些：

```bash
kubectl create deployment
kubectl get deployments
kubectl get pods
kubectl describe pod
kubectl set image
kubectl expose deployment
kubectl port-forward
kubectl scale deployment
kubectl get endpoints
kubectl rollout status
kubectl rollout history
kubectl rollout undo
```

但如果只记命令，这一课其实学得不算完整。

我觉得今天最重要的收获，是下面这几条理解：

### 1. Deployment 成功，不代表业务已经成功运行
它只代表我把“期望状态”交给了 K8s，真正能否跑起来还要看 Pod 的后续状态。

### 2. K8s 排障不能靠猜，要靠分层定位
今天我至少做了两次很典型的“分层定位”：

- `ErrImagePull` 时，先看 Events，再判断是仓库链路问题
- 页面打不开时，先用 `port-forward pod` 证明 Pod 没问题，再定位到 Service targetPort

### 3. Service 不是单个 Pod 的别名，而是一组 Pod 的稳定入口
这个理解是后面学习扩容、更新、故障恢复的基础。

### 4. Deployment 管的是目标状态，不是某个具体 Pod
我更新和回滚的对象始终是 Deployment，而不是手工去修某个 Pod。这也让我开始理解 Kubernetes 的声明式思路。

## 用一句话总结第一课

如果要用一句话总结今天这节课，我会写成：

**Kubernetes 的核心不是“把容器跑起来”，而是用声明式的方式管理一组可替换的 Pod，并通过稳定入口、滚动更新和回滚机制，让服务能够持续可用。**
