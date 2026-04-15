---
title: "我准备怎么用两台服务器做完一次运维实践任务：从环境准备到监控与日志的落地路线"
urlSlug: '20260413-02'
published: 2026-04-13
description: '一篇偏实践记录风格的文章：当我手上有一台本地服务器和一台公网云服务器时，应该怎么拆解 Ansible、k3s、Prometheus、Grafana 和 ELK 这类综合任务，以及每一步准备用什么命令落地。'
image: ''
tags: ['Ansible', 'k3s', 'Prometheus', 'Grafana', 'ELK', 'DevOps', '实践记录']
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

这次要做的不是单独学一个工具，而是把一整串东西串起来：

- Ansible
- k3s
- Prometheus
- Grafana
- ELK

如果只看名字，这种任务最容易给人一种压迫感：

**东西太多了，我根本不知道该先做什么。**

我一开始也是这个感觉。

不过这次和之前不一样的地方在于，我手上不是只有一台机器，而是两台：

- 一台本地服务器，准备专门拿来做 `k3s` 和实验环境
- 一台公网云服务器，适合承担对外访问、远程管理，以及一些更稳定的服务角色

有了两台机器之后，这件事就不应该再按“全塞到一台机器里”的思路来做了。

所以这篇文章，我不打算写成那种“概念解释型教程”，而是更像一份我自己的实践路线记录：

> **如果让我现在从零做完这次任务，我准备怎么拆、每一步先做什么、命令又该怎么下。**

## 先把目标说清楚

这次实践，我不会追求把环境搭成真正的生产架构，而是会追求：

**做出一套两台机器协作的最小可运行版本。**

也就是说：

- 本地服务器 `k3s` 负责跑 Kubernetes 实验环境
- 公网云服务器负责承担更适合公网访问和远程管理的角色
- Ansible 负责把环境初始化和批量配置理顺
- Prometheus + Grafana 负责监控
- ELK 负责日志

这样拆，比什么都塞在一台小机器里合理得多。

## 这两台机器我准备怎么分工

先把角色定清楚，后面做事才不会乱。

### 本地服务器：`k3s`
我准备用来做：

- k3s 集群本体（先单节点）
- Helm 部署练习
- Prometheus + Grafana 的 Kubernetes 内部署
- 一部分实验性服务

### 公网云服务器：`cloud-vps`
我准备用来做：

- 对外可访问的远程入口
- 后续可能的日志 / 辅助服务
- 远程管理和控制点
- 一部分更接近真实环境的服务练习

这么分工的好处是：

- k3s 跑在本地更灵活
- 公网机器不需要承受全部实验负载
- 角色更清楚，也更接近真实环境

## 第一步：先把两台机器的基础环境确认好

一开始不要急着装 k3s，也不要急着装 ELK。

先确认机器是不是在一个可管理状态里。

### 在两台机器上都先跑一遍这些命令

```bash
hostnamectl
uname -a
cat /etc/os-release
free -h
df -h
ip a
```

我想先知道：

- 系统版本
- 内存大概多少
- 磁盘空间够不够
- 网络接口情况

因为后面无论是 k3s、Grafana 还是 ELK，最后都会回到资源问题。

### 然后更新系统

如果是 Debian / Ubuntu：

```bash
apt update && apt upgrade -y
```

### 安装最基础的工具

```bash
apt install -y curl wget git vim htop unzip ca-certificates gnupg lsb-release jq
```

这一层如果不先整理好，后面每一步都会显得很别扭。

## 第二步：先把 SSH 管理体验理顺

因为这次是两台机器配合，我会先把 SSH 这层整理好。

例如本地管理机上准备 `~/.ssh/config`：

```text
Host k3s
    HostName 192.168.3.5
    User root
    IdentityFile ~/.ssh/id_ed25519

Host cloud-vps
    HostName your.server.ip
    User root
    IdentityFile ~/.ssh/id_ed25519
```

之后我就可以直接：

```bash
ssh k3s
ssh cloud-vps
```

这个小动作看起来不起眼，但后面做 Ansible 和日常操作时会顺很多。

## 第三步：先把 `k3s` 这台机器清到适合重新部署

因为 `k3s` 这台之前部署过 k3s，所以它不是一张白纸。

这种情况下，第一件事不是继续装，而是先确认旧环境已经清掉。

我现在会重点检查：

```bash
systemctl status k3s --no-pager || true
command -v k3s || true
command -v kubectl || true
ip link show cni0 2>/dev/null || true
ip link show flannel.1 2>/dev/null || true
iptables -S | grep -E "KUBE-|CNI-|flannel" || true
iptables -t nat -S | grep -E "KUBE-|CNI-|flannel" || true
```

如果这些都没有明显残留，那我就把它当成已经回到了“可重新部署”的状态。

## 第四步：用 Ansible 接管这两台机器

这一步我不想再手工来回配两遍。

既然任务里明确提到了 Ansible，那我会让它尽早上场。

### 我会先建一个最小目录

```bash
mkdir -p ~/lab-ops/ansible
cd ~/lab-ops/ansible
```

### inventory 先这样写

```ini
[local]
k3s ansible_host=192.168.3.5 ansible_user=root

[cloud]
cloud-vps ansible_host=your.server.ip ansible_user=root

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### 先来一个最小 playbook

```yaml
- hosts: all
  become: true
  tasks:
    - name: Update apt cache
      apt:
        update_cache: true

    - name: Install common packages
      apt:
        name:
          - curl
          - wget
          - git
          - vim
          - htop
          - unzip
          - jq
        state: present
```

### 跑法

```bash
ansible-playbook -i inventory.ini bootstrap.yml
```

这一步对我来说，重点不是“炫技”，而是：

- 后面重复执行不会乱
- 两台机器环境尽量一致
- 我不用手工反复点来点去

## 第五步：在 `k3s` 机器上重新部署 k3s

既然这台机器就是为 k3s 准备的，那这里直接上。

### 安装命令

```bash
curl -sfL https://get.k3s.io | sh -
```

### 安装后先看状态

```bash
systemctl status k3s --no-pager
kubectl get nodes
kubectl get pods -A
```

我会先看这三个命令的结果，再决定下一步。

如果 `kubectl get nodes` 里节点是 `Ready`，那说明这一层已经打底成功了。

## 第六步：在 k3s 上部署 Helm

Helm 几乎是后面装监控和日志时最顺手的方式。

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

这一步很简单，但后面能省很多事。

## 第七步：在 k3s 上部署 Prometheus + Grafana

这部分我会优先做，因为它最容易形成一个可验证成果。

### 添加仓库

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 创建命名空间

```bash
kubectl create namespace monitoring
```

### 安装 kube-prometheus-stack

```bash
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

### 查看 Pod 状态

```bash
kubectl get pods -n monitoring
```

如果 Pod 比较多，不要一上来就慌。先看：

- 是不是 `ImagePullBackOff`
- 是不是资源不够
- 是不是 `Pending`

### 进一步排错

```bash
kubectl describe pod <pod-name> -n monitoring
kubectl logs <pod-name> -n monitoring
```

## 第八步：把 Grafana 页面访问出来

对我来说，监控这一步算不算真正落地，很大程度取决于：

**我能不能真的把 Grafana 页面打开。**

最简单的临时方式通常是端口转发：

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

然后本地浏览器访问：

```text
http://127.0.0.1:3000
```

如果只是练习，先这样就够了。

## 第九步：ELK 我会最后做

这不是因为它不重要，而是因为它通常最重、最容易拖慢进度。

### 这次我会怎么定目标

我不会一上来就追求一套很完整、很漂亮的 ELK 生产结构。

我更现实的目标会是：

- 先把 Elasticsearch 跑起来
- 再把 Kibana 跑起来
- 最后确认至少能看到一条日志

### 如果用 Docker 先做最小实验

例如在公网机器上先单独跑：

```bash
docker run -d --name elasticsearch \
  -p 9200:9200 \
  -e discovery.type=single-node \
  -e xpack.security.enabled=false \
  docker.elastic.co/elasticsearch/elasticsearch:8.13.4
```

然后再跑 Kibana：

```bash
docker run -d --name kibana \
  -p 5601:5601 \
  -e ELASTICSEARCH_HOSTS=http://your.server.ip:9200 \
  docker.elastic.co/kibana/kibana:8.13.4
```

### 先验证 Elasticsearch

```bash
curl http://127.0.0.1:9200
```

### 再验证 Kibana

浏览器访问：

```text
http://your.server.ip:5601
```

对这次实践来说，我会先把 ELK 做到“最小可见成果”就行，不会让它一上来把整套任务节奏拖死。

## 第十步：怎么验收这次实践

做到后面，很容易出现一种情况：

- 每个东西好像都装了一点
- 但自己也说不清到底算不算完成

所以我会明确给自己列验收项。

### 基础环境

```bash
ssh k3s
ssh cloud-vps
```

都正常。

### Ansible

```bash
ansible all -i inventory.ini -m ping
ansible-playbook -i inventory.ini bootstrap.yml
```

至少能成功跑一次。

### k3s

```bash
kubectl get nodes
kubectl get pods -A
```

能看到节点 ready。

### Prometheus + Grafana

```bash
kubectl get pods -n monitoring
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Grafana 页面能打开。

### ELK

```bash
docker ps
curl http://127.0.0.1:9200
```

至少 Elasticsearch 正常，Kibana 页面能开。

## 这次实践里，我最不想踩的坑

如果按我自己的习惯，我会刻意避开这几个坑：

### 1）一开始就想把所有东西都做成生产级

没必要。

这次更重要的是闭环，不是完美。

### 2）把 ELK 放得太早

它太重，放前面很容易把节奏拖垮。

### 3）没先把 SSH 和基础环境理顺

一旦基础环境乱，后面所有工具都只是在放大混乱。

## 写在最后

这次任务如果只看工具列表，确实会让人一开始有点发怵。

但如果真的拆开以后，其实会发现最重要的事情没有那么多：

- 先把两台机器角色分清楚
- 先把基础环境和 SSH 管理理顺
- 再用 Ansible 接管初始化
- 再上 k3s
- 再做监控
- 最后补日志

我现在更倾向于把它理解成：

> **不是一次学会五六个工具，而是练习怎么把一组工具按正确顺序落地。**

只要这条顺序走顺了，整件事就不会显得那么吓人。
