---
title: "为什么我的 kube-prometheus-stack 总装不上：从 Helm 报错到 k3s 代理配置的排查记录"
urlSlug: '20260420-02'
published: 2026-04-20
description: '记录一次在 k3s 上部署 kube-prometheus-stack 的真实排障过程：为什么一开始我以为是 Ansible 或 Helm 命令有问题，后来才发现真正的根因是 k3s/containerd 没有吃到代理环境，导致连 pause 镜像都拉不下来。'
image: ''
tags: ['k3s', 'Helm', 'Prometheus', 'Grafana', 'Ansible', 'Kubernetes', '问题排查']
category: '问题排查'
draft: false 
lang: 'zh_CN'
---

这次我本来只是想按既定步骤，把 `kube-prometheus-stack` 收进 Ansible。

最开始看起来像是一个很普通的问题：

- `ansible-playbook -i inventory.ini playbooks/monitoring.yml`
- 卡在 `Install kube-prometheus-stack`
- 一会儿超时，一会儿又报错

如果只看表面，很容易以为是：

- Ansible 写错了
- Helm 命令不对
- kube-prometheus-stack 太大
- GitHub 网络不稳定

我一开始也是这么猜的。

但这次排到最后，真正的根因其实比“Helm 安装失败”更底层一些。

> **不是 Ansible 本身的问题，而是 k3s / containerd 没有正确吃到代理，导致集群连最基础的镜像都拉不下来。**

这篇就按真实排障顺序，把这个过程记下来。

## 一开始的现象是什么

最开始是在执行下面这条命令时出问题：

```bash
ansible-playbook -i inventory.ini playbooks/monitoring.yml
```

对应的 playbook 里，关键安装步骤大概是：

```yaml
- name: Install kube-prometheus-stack
  shell: helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

一开始出现过这种报错：

```text
Error: Kubernetes cluster unreachable: Get "http://localhost:8080/version": dial tcp [::1]:8080: connect: connection refused
```

这个问题后来很好定位，就是 Helm 没拿到 k3s 的 kubeconfig。

修法也很直接：

```bash
KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

或者在 Ansible 里统一加：

```yaml
environment:
  KUBECONFIG: /etc/rancher/k3s/k3s.yaml
```

这一步修完以后，表面上像是已经走对了。

但新的问题又来了。

## 第二阶段：不是连不上集群，而是下载会超时

后面开始出现的报错，变成了这种：

```text
context deadline exceeded
```

以及：

```text
unexpected EOF
```

这时候直觉上很容易继续往 Helm 那边想，比如：

- chart 太大
- GitHub 下载慢
- Ansible 卡住没进度

为了排查，我当时做了几件事：

### 1. 单独测试主 chart 能不能拉

```bash
helm pull prometheus-community/kube-prometheus-stack
```

能成功。

### 2. 单独测试依赖 chart 能不能拉

例如：

```bash
helm pull grafana/grafana
```

也能成功。

这就让问题变得很怪：

- 单独 `pull` 看起来没问题
- 但 `helm upgrade --install` 还是会失败

如果到这里就停下来，其实还是很容易误判。

## 第三阶段：手动执行 Helm，发现也不是 Ansible 特有的问题

为了排除 Ansible 执行环境影响，我直接在 k3s 机器上手动跑：

```bash
helm repo update
KUBECONFIG=/etc/rancher/k3s/k3s.yaml helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace --debug
```

这一步让我确认了一件事：

> **问题不是 Ansible 专有的。**

因为直接在节点上手工执行，依然会失败。

也就是说，这不是：

- playbook 语法问题
- Ansible shell 模块问题
- inventory 配错

真正的问题还是在 k3s 节点本身。

## 第四阶段：Helm 只是表象，真正的问题出在 Pod 根本起不来

后面继续查 `kubectl get pods -A` 和 `kubectl get events -A`，这一步非常关键。

我最后看到的不是某个 Prometheus Pod 单独挂掉，而是更底层的异常：

- `coredns` 卡在 `ContainerCreating`
- `metrics-server` 卡在 `ContainerCreating`
- `local-path-provisioner` 卡在 `ContainerCreating`
- `helm-install-traefik` 卡在 `ContainerCreating`
- `monitoring-kube-prometheus-admission-create` 也卡着起不来

这时候就该警惕了。

因为如果连这些基础组件都起不来，那就不能再把锅只甩给 `kube-prometheus-stack` 了。

继续看事件，真正关键的报错是这个：

```text
failed to get sandbox image "rancher/mirrored-pause:3.6"
failed to pull image "rancher/mirrored-pause:3.6"
failed to resolve reference "docker.io/rancher/mirrored-pause:3.6"
dial tcp ...:443: i/o timeout
```

看到这里，其实方向就已经彻底变了。

## 真正根因：k3s / containerd 没有代理

Kubernetes 创建 Pod 时，最开始要先准备 sandbox。

而 sandbox 会依赖一个很基础的镜像：

```text
docker.io/rancher/mirrored-pause:3.6
```

如果这个镜像都拉不下来，那后面所有 Pod 都会卡住。

这时候我直接在 k3s 节点上手动测试：

```bash
ctr -n k8s.io images pull docker.io/rancher/mirrored-pause:3.6
```

结果就是超时。

到这里，根因就坐实了：

> **不是 Helm 本身坏了，而是 k3s/containerd 没拿到代理环境，导致它无法从 Docker Hub 拉镜像。**

这也是为什么前面会出现那种很迷惑的现象：

- shell 里某些 `curl` 或 `helm pull` 看起来能通
- 但集群真正创建 Pod 时还是失败

因为：

- 你手工执行的命令，可能跑在当前 shell 环境里
- `k3s` / `containerd` 是 systemd 管的服务进程
- **systemd 服务并不会自动继承你当前终端里的代理变量**

这就是这次最核心的坑。

## 正确修法是什么

既然问题出在 `k3s` 服务本身没吃到代理，那修法就应该配在 systemd 上，而不是只改当前 shell。

一个常见做法是给 `k3s` 写 override：

```bash
mkdir -p /etc/systemd/system/k3s.service.d
cat >/etc/systemd/system/k3s.service.d/http-proxy.conf <<'EOF'
[Service]
Environment="HTTP_PROXY=http://你的代理地址"
Environment="HTTPS_PROXY=http://你的代理地址"
Environment="NO_PROXY=127.0.0.1,localhost,10.42.0.0/16,10.43.0.0/16,10.0.0.0/8,192.168.0.0/16"
EOF
```

然后：

```bash
systemctl daemon-reload
systemctl restart k3s
```

重启以后，再验证：

```bash
systemctl show k3s --property=Environment
ctr -n k8s.io images pull docker.io/rancher/mirrored-pause:3.6
```

只要 `ctr pull` 能通，后面的方向基本就对了。

## 修好之后的结果

代理补到 k3s 服务以后，再看集群状态，之前那些卡住的基础组件就陆续恢复了：

- `coredns` 正常运行
- `metrics-server` 正常运行
- `local-path-provisioner` 正常运行
- `traefik` 正常运行

然后再装 `kube-prometheus-stack`，也就顺利落地了。

最终 monitoring 命名空间里的核心组件都能正常起来，例如：

- `monitoring-grafana`
- `monitoring-kube-prometheus-operator`
- `monitoring-kube-state-metrics`
- `monitoring-prometheus-node-exporter`
- `prometheus-monitoring-kube-prometheus-prometheus-0`
- `alertmanager-monitoring-kube-prometheus-alertmanager-0`

到这里，才算是真正把问题解决掉。

## 这次排障里最值得记住的经验

如果把这次经历压缩一下，我觉得最值得记住的是下面几条。

### 1）不要太早把锅甩给 Ansible

只要是通过 Ansible 执行 shell 命令出错，很多人第一反应都会怀疑：

- playbook 写错了
- become 没生效
- 环境变量没传进去

这些当然要查，但别在第一步就把视线锁死在 Ansible 上。

因为像这次，真正的根因其实在更底层：

- k3s
- containerd
- 节点拉镜像

### 2）Helm 能拉 chart，不等于集群就能跑起来

这点很容易混。

- `helm pull` 成功，只能说明 chart 包能下载
- `helm upgrade --install` 成功，还要看依赖 chart、集群 API、Pod 创建、镜像拉取

这几层不是一回事。

### 3）看到 `ContainerCreating` 很久不动，就该去看 events

很多排障卡住，是因为只盯着 Helm 输出看。

更有效的做法通常是：

```bash
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
```

这次真正有用的信息，其实就是在 events 里看到的：

- `FailedCreatePodSandBox`
- `failed to get sandbox image`
- `i/o timeout`

### 4）给 shell 配代理，不等于给 systemd 服务配了代理

这是这次最核心、也最容易忽略的一点。

你以为“我机器明明有代理”，但实际上：

- shell 有代理
- root 用户有代理
- 某些命令能通
- 但 systemd 里的 `k3s` 并没有代理

最后真正工作时的 containerd，还是拉不动镜像。

## 写在最后

这次排下来，我最大的感受不是“Helm 真麻烦”，而是：

> **Kubernetes 里的很多报错，最后真正的根因往往不在你第一眼看到的那一层。**

表面看是：

- Ansible 卡在 `Install kube-prometheus-stack`
- Helm 安装超时
- Grafana / Prometheus 没起来

但往下追，真正的问题其实是：

- Pod sandbox 拉不起来
- pause 镜像拉不下来
- k3s/containerd 没有代理

所以以后如果你也遇到类似情况，我会更建议按这个顺序查：

1. 先确认 Helm 是不是拿到了 kubeconfig
2. 再确认 Helm 安装失败是不是只是表象
3. 去看 `kubectl get pods -A`
4. 去看 `kubectl get events -A`
5. 直接测试 `ctr -n k8s.io images pull`
6. 最后再判断是不是 k3s / containerd 的代理问题

这样会比一直围着 `helm upgrade --install` 打转高效很多。