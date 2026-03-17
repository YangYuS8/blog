---
title: "从 Docker 到 Kubernetes：我在 Arch Linux 上搭起第一个 K8s 集群"
urlSlug: '20260318-01'
published: 2026-03-18
description: '记录我在 EndeavourOS 上学习 Kubernetes 的第一天：从 kind 建集群、Deployment 部署应用，到排查镜像拉取失败与 Service 端口映射问题。'
image: ''
tags: ['kubernetes', 'k8s', 'docker', 'kind', 'archlinux', 'endeavouros']
category: '云原生'
draft: false 
lang: 'zh_CN'
---
今天是我系统学习 Kubernetes 的第一天。和以往只停留在“知道 Pod、Deployment、Service 这些名词”不同，这次我决定直接在自己的电脑上动手，把一个本地 K8s 集群真正跑起来。

我的机器环境比较适合做本地实验：系统是 **EndeavourOS（Arch 系）**，内核版本 **Linux 6.19.8**，CPU 是 **i7-12700H**，内存 **31GB**，磁盘和 Docker 环境都比较充足。对我来说，这样的本地环境有一个很大的好处：可以反复试错，出问题就删掉重来，不需要一开始就上云服务器，也不用先碰复杂的生产级安装。

## 为什么我没有一开始就装 kubeadm

如果目标是“学会熟练部署 K8s”，很多人的第一反应可能是直接去装 kubeadm，甚至想一步到位搭一个“像生产一样”的集群。但对我当前阶段来说，这样做并不是最高效的路径。

我已经有 Docker 基础，会写 Dockerfile，也理解镜像、容器和端口映射这些概念。所以更合适的方式，不是先和证书、etcd、控制平面安装细节死磕，而是先用一个更轻量的本地集群工具，把 Kubernetes 最核心的使用链路跑通。

因此，我今天选择的是：

- 用 **Docker** 作为容器运行环境
- 用 **kind** 创建本地 Kubernetes 集群
- 用 **kubectl** 管理集群和应用

这条路线更像是“先学会怎么开车，再研究发动机怎么装”。

## 今天的起点：先确认宿主机环境

开始之前，我先检查了本机的 Docker 环境。结果显示：

- Docker 已经正常安装
- Docker daemon 可以正常运行
- 本机容器运行环境没有明显异常
- 但 `kind` 和 `kubectl` 还没有安装

这一步虽然简单，但它提醒了我一件事情：**Kubernetes 的问题，很多时候并不一定是 Kubernetes 本身的问题。**

如果宿主机的容器环境都不完整，后续很多现象都会变得混乱。与其在 K8s 里盲猜，不如先把底层依赖确认清楚。

## 第一个集群：kind 创建本地 Kubernetes 集群

安装好 `kubectl` 和 `kind` 之后，我创建了自己的第一个本地集群：

```bash
kind create cluster --name lab
kubectl cluster-info --context kind-lab
kubectl get nodes
```

这一步让我第一次真正体会到：**Kubernetes 并不是一个抽象概念，而是一个我可以在自己电脑上实际操作的系统。**

当 `kubectl get nodes` 返回 `Ready` 的节点时，我知道本地集群已经真正启动起来了。虽然它只有一个节点，但这已经足够让我学习 K8s 最常见的部署与排障流程。

## 第一次部署应用：Deployment 成功了，但 Pod 没跑起来

随后，我尝试部署一个最熟悉的应用：nginx。

```bash
kubectl create deployment nginx --image=nginx
kubectl get deployments
kubectl get pods -o wide
```

命令执行后，Deployment 确实创建成功了，但 Pod 却没有进入 `Running`，而是停在了：

```text
ErrImagePull
ImagePullBackOff
```

这是我今天遇到的第一个真实问题。

刚开始看到这个错误时，我本能地会想：“是不是 Deployment 写错了？是不是 Kubernetes 有问题？”但后面的排查让我认识到，**K8s 排障最重要的不是猜，而是缩小范围。**

## 第一次排障：不是 YAML 写错，而是镜像拉不下来

为了弄清楚问题原因，我查看了 Pod 的事件信息：

```bash
kubectl describe pod <pod-name>
```

在 `Events` 里，我看到了关键报错：

- 拉取镜像 `docker.io/library/nginx:latest` 超时
- 访问 `registry-1.docker.io` 和认证服务时失败

这一步非常重要，因为它直接说明：

- **Deployment 已经创建成功**
- **调度器已经把 Pod 分配到了节点上**
- 真正失败的是 **容器运行时拉镜像** 这一步

也就是说，问题不在 Kubernetes 资源对象本身，而在**镜像获取链路**。

## 继续缩小范围：问题不只是 kind，连宿主机 Docker 也拉不到 Docker Hub

为了判断问题到底出在 kind 节点里，还是出在宿主机本身，我继续在宿主机直接执行：

```bash
docker pull nginx
```

结果同样失败，而且报错和 Pod 里几乎一致。这说明：

**不是 K8s 不会拉镜像，而是宿主机到 Docker Hub 的链路本来就有问题。**

继续检查后，我确认了几个事实：

1. 我的系统使用了本地代理 `127.0.0.1:7890`
2. 宿主机直连 `auth.docker.io` 和 `registry-1.docker.io` 都不通
3. 通过代理访问时，`registry-1.docker.io` 可以响应，但 `auth.docker.io` 的 TLS 链路异常
4. Docker Hub 这一条链路不稳定，但其他镜像仓库并不一定有问题

这让我学到了一个非常实用的运维思路：

> 遇到镜像拉取失败，不要立刻怀疑 K8s 配置；先区分是 Kubernetes 配置错误，还是网络、代理、镜像仓库可达性的问题。

## 临时绕过问题：换一个可用的镜像仓库

既然 Docker Hub 当前链路有问题，我没有继续死磕，而是改成测试其他镜像源：

```bash
docker pull registry.k8s.io/pause:3.10
docker pull quay.io/nginx/nginx-unprivileged:stable
```

结果这两个镜像都可以正常拉取。

于是我直接更新了 Deployment 的镜像：

```bash
kubectl set image deployment/nginx nginx=quay.io/nginx/nginx-unprivileged:stable
kubectl get pods -w
```

这时，我第一次完整看到了一次 Kubernetes 的滚动更新过程：

- 旧 Pod 因为镜像拉取失败而处于异常状态
- Deployment 更新镜像后，创建了新的 Pod
- 新 Pod 成功进入 `Running`
- 旧 Pod 被逐步终止

这让我第一次真正理解了一句话：

**我改的是 Deployment，但变化最终发生在 Pod 身上。**

换句话说，Deployment 不是“直接运行容器”的对象，它更像是一个“声明式的控制器”：我告诉它“我要什么状态”，它负责把这个状态落实成 Pod。

## 我对三个核心对象的第一版理解

今天学完之后，我对 Kubernetes 里三个最关键对象的理解，终于不再只是死记硬背：

### 1. Pod：真正运行容器的地方

Pod 是最小运行单元。容器真正跑在 Pod 里面，所以如果应用有没有启动、端口有没有监听、日志有没有报错，本质上都要回到 Pod 去看。

### 2. Deployment：管理 Pod 的期望状态

Deployment 不直接处理请求，也不直接对外提供访问入口。它的核心职责是：

- 用什么镜像
- 保持几个 Pod 副本
- Pod 挂了之后如何补齐
- 更新镜像时如何滚动替换旧 Pod

所以它更像是“应用运行状态的管理者”。

### 3. Service：给一组 Pod 提供稳定入口

Service 解决的是访问问题。因为 Pod 会重建、IP 会变化，所以不能直接依赖某个 Pod 的地址。Service 会把流量转发到一组符合条件的 Pod 上，让访问方始终有一个稳定的入口。

这是我今天第一次真正理解的一个关键点：

**Service 面向的是一组 Pod，而不是某一个固定 Pod。**

## 第二个问题：Pod 是 Running，但页面依然打不开

新 Pod 跑起来之后，我继续执行：

```bash
kubectl expose deployment nginx --port=80 --type=ClusterIP
kubectl port-forward svc/nginx 8080:80
```

按理说，浏览器访问 `http://127.0.0.1:8080` 应该可以看到 nginx 页面，但实际却打不开。

这时我一开始的直觉是：“是不是 Service 拒绝了连接？”

现在回过头看，这其实是一个很典型的初学者思路：看到“访问失败”，就先怀疑 Service 本身坏了。但更合理的做法应该是：**先分层验证链路。**

## 第二次排障：Pod 能访问，Service 不通，问题在端口映射

为了判断问题是在 Pod 还是在 Service，我先直接转发到 Pod：

```bash
kubectl port-forward pod/<pod-name> 8080:8080
```

结果页面可以打开。

这说明：

- Pod 里的 nginx 是正常工作的
- 容器本身没有崩溃
- 应用监听端口没有问题

然后我修正了 Service：

```bash
kubectl delete svc nginx
kubectl expose deployment nginx --port=80 --target-port=8080 --type=ClusterIP
kubectl port-forward svc/nginx 8080:80
```

页面恢复正常。

这时问题就很清楚了：

- 我使用的不是默认官方 `nginx` 镜像，而是 `nginx-unprivileged`
- 这个镜像在容器内监听的端口不是 `80`，而是 `8080`
- 我最初创建的 Service 没有显式指定 `targetPort`
- 所以 Service 把流量转发到了错误的后端端口

这个问题让我学到了今天最有价值的网络概念：

> **Service 能不能访问成功，不只取决于它“有没有创建出来”，还取决于它“转发到了正确的 Pod 端口”。**

## 今天最大的收获：K8s 不只是会用命令，更重要的是会分层排查

如果只看“操作层面”，我今天学到的命令并不算多：

```bash
kubectl get deployments
kubectl get pods
kubectl get svc
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl set image deployment/<name> <container>=<image>
kubectl expose deployment <name> --port=80 --target-port=8080 --type=ClusterIP
kubectl port-forward pod/<pod> 8080:8080
kubectl port-forward svc/<svc> 8080:80
```

但比命令更重要的是，我开始建立了一个正确的排障顺序：

1. 先确认对象有没有创建成功
2. 再确认失败发生在哪一层
3. Pod 不通就查容器和镜像
4. Pod 能通、Service 不通就查 selector 和端口映射
5. 镜像拉不下来时，优先检查网络、仓库和代理，而不是盲改 YAML

这套思路，以后无论是学 Ingress、ConfigMap、PVC，还是更复杂的多服务部署，都会继续复用。

## 结合我自己的目标，今天这一步为什么有意义

我学习 Go、Linux 和云原生，不只是出于兴趣，更现实的目标是为了找工作。对我来说，Kubernetes 不是一个“了解一下就行”的名词，而是一项很可能出现在求职面试和真实工作环境里的技能。

今天这次练习的意义，不在于我已经“学会了 Kubernetes”，而在于我迈出了正确的一步：

- 我没有停留在概念背诵上
- 我真正搭起了本地集群
- 我实际部署了应用
- 我亲手处理了镜像拉取失败
- 我亲手定位并修复了 Service 端口映射问题

这些经历会让我之后再看到 `ErrImagePull`、`ImagePullBackOff`、`port-forward`、`targetPort` 这些词时，不再只是“眼熟”，而是能联想到真实场景和解决路径。

## 下一步我准备学什么

今天的内容还只是开始。接下来，我准备继续把下面几块补上：

1. **Deployment 的副本数与滚动更新**理解为什么 Service 面向的是一组 Pod，而不是某一个固定 Pod。
2. **查看 Endpoints 与标签选择器**理解 Service 到底是如何找到后端 Pod 的。
3. **ConfigMap 和 Secret**学会把配置和敏感信息从镜像中解耦出来。
4. **Ingress**学习如何通过更接近真实生产环境的方式暴露 HTTP 服务。
5. **k3s 或 kubeadm**
   等基础使用更熟练后，再进入更真实的集群安装与运维阶段。

## 写在最后

学 Kubernetes 的第一天，我没有一帆风顺，甚至可以说刚开始就接连撞墙：先是镜像拉不下来，后来是页面打不开。

但正因为这些问题都是真实发生的，我反而觉得今天收获很大。

如果只是照着教程一路复制命令然后看到成功页面，我可能会以为自己“会了”；但真正遇到故障、分析原因、修正配置之后，我才开始真正理解 Kubernetes 的工作方式。

对于一个想把 K8s 作为长期技能来掌握的人来说，这样的第一天，比“顺顺利利跑通一个 demo”更有价值。
