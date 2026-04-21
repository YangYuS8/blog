---
title: "我准备怎么用一台服务器做完一次运维实践任务：从环境准备到监控与日志的落地路线"
urlSlug: '20260413-02'
published: 2026-04-13
description: '一篇偏实践记录风格的文章：当我手上只有一台 k3s 服务器时，怎样以 Ansible 为主线，把环境初始化、k3s、Prometheus、Grafana 和 Loki 一步步自动化落地。'
image: ''
tags: ['Ansible', 'k3s', 'Prometheus', 'Grafana', 'Loki', 'DevOps', '实践记录']
category: '编程实践'
draft: false 
lang: 'zh_CN'
---

这次要做的不是单独学一个工具，而是把一整串东西串起来：

- Ansible
- k3s
- Prometheus
- Grafana
- Loki

如果只看名字，这种任务最容易给人一种压迫感：

**东西太多了，我根本不知道该先做什么。**

我一开始也是这个感觉。

不过现在这个实践已经比最开始更清楚了，因为目标被收窄到了只有一台机器，也就是 `k3s` 那台服务器。

这样反而更适合先把整条自动化路线练顺。

所以这篇文章，我不再按“两台机器分工”的思路写，而是直接按一台服务器的实际场景来拆：

- 一台服务器能承担什么
- Ansible 怎么组织目录
- 哪些事情交给 Ansible
- 怎样让 k3s、Prometheus、Grafana 进入自动化流程
- 日志服务怎么作为补充落进去

## 先把目标说清楚

这次实践，我不会追求真正的生产架构，而是追求：

**做出一套单机可运行、并且能够重复执行的最小自动化版本。**

也就是说：

- `k3s` 这台机器同时承担实验环境本体
- Ansible 负责把环境初始化、k3s、Helm、Prometheus、Grafana 这些步骤串起来
- Loki 先按最小实验版本去落地

这样做的重点不是“把所有东西都堆得很大”，而是：

- 先把顺序走通
- 先把自动化思路理顺
- 以后重做时不需要从头手敲

## 这一台服务器我准备怎么用

既然只剩下一台机器，那它就要承担这次实践里的主要角色。

### `k3s` 这台机器我准备用来做

- k3s 单节点集群
- Helm 部署练习
- Prometheus + Grafana 的 Kubernetes 内部署
- 一部分日志服务实验

这样做虽然不算“分层很漂亮”，但对当前这个阶段反而更合适。

因为你现在最需要的不是一套复杂分布式架构，而是：

> **先把一条完整的自动化部署链路跑通。**

## 第一步：先把 SSH 管理理顺

后面所有自动化都要建立在 SSH 能稳定连接的基础上，所以这一步不能省。

先在管理机上准备 `~/.ssh/config`：

```text
Host k3s
    HostName 192.168.3.5
    User root
    IdentityFile ~/.ssh/id_ed25519
```

然后先手工确认：

```bash
ssh k3s hostname
```

如果这一步不顺，后面不要急着怪 Ansible，应该先把 SSH 打通。

## 第二步：先搭一个最小的 Ansible 目录

我会先建一个自己的工作目录：

```bash
mkdir -p ~/lab-ops/ansible/{group_vars,host_vars,playbooks}
cd ~/lab-ops/ansible
```

目录我会先做成这样：

```text
ansible/
├── inventory.ini
├── group_vars/
├── host_vars/
└── playbooks/
    ├── bootstrap.yml
    ├── k3s.yml
    ├── monitoring.yml
    └── logging.yml
```

这次的目标不是把目录做得多复杂，而是让后面的自动化步骤都有地方放。

## 第三步：把 inventory 写清楚

```ini
[k3s_nodes]
k3s ansible_host=192.168.3.5 ansible_user=root

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

因为现在只有一台机器，所以 inventory 反而更简单。

## 第四步：先用 Ansible 做基础初始化

先做最基础的一层，目的是把这台机器整理到可继续自动化的状态。

### `playbooks/bootstrap.yml`

```yaml
- hosts: k3s_nodes
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
          - ca-certificates
        state: present
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/bootstrap.yml
```

这一层做完以后，至少先有一个统一起点。

## 第五步：让 Ansible 接管 k3s 安装

这一步开始，Ansible 就不只是“初始化工具”了。

### `playbooks/k3s.yml`

```yaml
- hosts: k3s_nodes
  become: true
  tasks:
    - name: Install k3s
      shell: curl -sfL https://get.k3s.io | sh -
      args:
        creates: /usr/local/bin/k3s

    - name: Ensure k3s service is enabled
      service:
        name: k3s
        state: started
        enabled: true

    - name: Create kubectl symlink
      file:
        src: /usr/local/bin/k3s
        dest: /usr/local/bin/kubectl
        state: link
        force: true

    - name: Check node status
      shell: kubectl get nodes
      environment:
        KUBECONFIG: /etc/rancher/k3s/k3s.yaml
      register: k3s_nodes_result
      changed_when: false

    - name: Show node status
      debug:
        var: k3s_nodes_result.stdout_lines

    - name: Install Helm
      shell: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      args:
        creates: /usr/local/bin/helm
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/k3s.yml
```

这里的重点不是把 `curl | sh` 包了一层，而是：

- 以后重装时可以重复跑
- k3s 安装被纳入了统一流程
- Helm 也顺手接进来了

## 第六步：把 Prometheus + Grafana 收进 Ansible

如果这一步还继续手工装，那前面 Ansible 的价值就还是没有完全发挥出来。

所以我会直接把监控也写成 playbook。

### `playbooks/monitoring.yml`

```yaml
- hosts: k3s_nodes
  become: true
  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    HTTP_PROXY: http://192.168.3.14:7890/
    HTTPS_PROXY: http://192.168.3.14:7890/
    NO_PROXY: 127.0.0.1,localhost,10.42.0.0/16,10.43.0.0/16,10.0.0.0/8,192.168.0.0/16
  tasks:
    - name: Add Prometheus Helm repo
      shell: helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      register: helm_repo_add
      failed_when: helm_repo_add.rc != 0 and 'already exists' not in helm_repo_add.stderr
      changed_when: "'has been added' in helm_repo_add.stdout"

    - name: Add Grafana Helm repo
      shell: helm repo add grafana https://grafana.github.io/helm-charts
      register: grafana_repo_add
      failed_when: grafana_repo_add.rc != 0 and 'already exists' not in grafana_repo_add.stderr
      changed_when: "'has been added' in grafana_repo_add.stdout"

    - name: Update Helm repos
      shell: helm repo update
      changed_when: false

    - name: Create monitoring namespace
      shell: kubectl create namespace monitoring
      register: monitoring_ns
      failed_when: monitoring_ns.rc != 0 and 'already exists' not in monitoring_ns.stderr
      changed_when: "'created' in monitoring_ns.stdout"

    - name: Write monitoring values
      copy:
        dest: /root/monitoring-values.yaml
        mode: '0644'
        content: |
          grafana:
            service:
              type: NodePort
              nodePort: 30080

    - name: Install kube-prometheus-stack
      shell: helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f /root/monitoring-values.yaml
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/monitoring.yml
```

这一层里我更倾向于把和监控部署直接相关的环境一起放进 playbook，例如：

- `KUBECONFIG`
- `HTTP_PROXY`
- `HTTPS_PROXY`
- `NO_PROXY`

同时，如果后面准备让外部机器通过 Tailscale 或反向代理访问 Grafana，我也更建议直接把 Grafana 的 service 形式写进 Helm values，而不是装完以后再临时手工 patch。

这样做的好处是：

- Helm 访问仓库时有稳定的网络出口
- kubectl 与 Helm 都能直接找到 k3s 集群
- 以后重跑 playbook 时不依赖当前 shell 是否手工 export 过环境变量
- Grafana 暴露方式可以跟着 release 一起管理，不会在重装后丢失

如果你的代理地址、网段或者 NodePort 端口号跟这里不同，就把示例里的值替换成你自己的实际环境。

### 部署后怎么确认

```bash
ssh k3s sudo kubectl get pods -n monitoring
ssh k3s sudo kubectl get svc -n monitoring
```

如果只是临时访问 Grafana，依然可以端口转发：

```bash
ssh k3s sudo kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

浏览器访问：

```text
http://127.0.0.1:3000
```

## 第七步：日志服务怎么放进这条自动化路线

日志这部分我更倾向于直接走 Loki，而不是继续用 Docker 临时跑一套 ELK。

原因很简单：

- 它更贴近 `k3s` / `Kubernetes` 的使用场景
- 它和前面已经部署好的 `Grafana` 更容易接起来
- 采集层可以直接按节点方式运行，而不是额外再拼一套偏传统的日志平台

如果你前面已经看过我写的 Loki 文章，这里可以一起参考：

- [如何在 k3s 里部署和使用 Loki：按官方当前推荐路线完成一次最小可用实践](/posts/20260421-02/)

另外，前面监控这部分如果想补概念，也可以结合这两篇一起看：

- [Prometheus 是什么，为什么大家都用它做监控：给新手的一篇入门指南](/posts/20260412-03/)
- [Grafana 是什么，为什么它总和 Prometheus 一起出现：给新手的一篇入门指南](/posts/20260412-02/)
- [Helm 是什么，应该怎么安装和使用：给 Kubernetes 新手的一篇实战入门](/posts/20260420-01/)

### `playbooks/logging.yml`

```yaml
- hosts: k3s_nodes
  become: true
  environment:
    KUBECONFIG: /etc/rancher/k3s/k3s.yaml
    HTTP_PROXY: http://192.168.3.14:7890/
    HTTPS_PROXY: http://192.168.3.14:7890/
    NO_PROXY: 127.0.0.1,localhost,10.42.0.0/16,10.43.0.0/16,10.0.0.0/8,192.168.0.0/16
  tasks:
    - name: Add Grafana Helm repo
      shell: helm repo add grafana https://grafana.github.io/helm-charts
      register: grafana_repo_add
      failed_when: grafana_repo_add.rc != 0 and 'already exists' not in grafana_repo_add.stderr
      changed_when: "'has been added' in grafana_repo_add.stdout"

    - name: Update Helm repos
      shell: helm repo update
      changed_when: false

    - name: Create logging namespace
      shell: kubectl create namespace logging
      register: logging_ns
      failed_when: logging_ns.rc != 0 and 'already exists' not in logging_ns.stderr
      changed_when: "'created' in logging_ns.stdout"

    - name: Write Loki values
      copy:
        dest: /root/loki-values.yaml
        mode: '0644'
        content: |
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

    - name: Install Loki
      shell: helm upgrade --install loki grafana/loki -n logging --create-namespace -f /root/loki-values.yaml
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/logging.yml
```

这一步我这里先只把 Loki 后端收进 Ansible，目的是让日志系统至少先有一个可复用的后端入口。

如果后面要继续把采集层也自动化进来，就继续在这套 playbook 基础上补 Grafana Alloy。

## 第八步：这一套自动化路线到底长什么样

如果我把整件事按执行顺序排出来，大概就是：

```bash
cd ~/lab-ops/ansible

ansible-playbook -i inventory.ini playbooks/bootstrap.yml
ansible-playbook -i inventory.ini playbooks/k3s.yml
ansible-playbook -i inventory.ini playbooks/monitoring.yml
ansible-playbook -i inventory.ini playbooks/logging.yml
```

这四步跑完以后，整套环境至少会比较接近：

- 基础环境已经初始化
- k3s 已经部署
- Helm 已经安装
- Prometheus + Grafana 已经落地
- Loki 后端已经落地

这时候你再回头看，就会发现 Ansible 已经不只是“装几个包”，而是真的在承担整套部署流程的主线角色。

## 第九步：怎么验收这次实践

如果做到后面没有一个明确验收表，很容易出现一种情况：

- 每个步骤都做了一点
- 但自己也说不清到底算不算完成

所以我会给自己列最小验收项。

### 基础连接

```bash
ssh k3s hostname
```

### Ansible 可用

```bash
ansible all -i inventory.ini -m ping
```

### k3s 正常

```bash
ssh k3s kubectl get nodes
ssh k3s kubectl get pods -A
```

### 监控正常

```bash
ssh k3s kubectl get pods -n monitoring
ssh k3s kubectl get svc -n monitoring
```

Grafana 页面能访问。

### 日志服务正常

```bash
ssh k3s sudo kubectl get pods -n logging
ssh k3s sudo kubectl get svc -n logging
```

至少 Loki 相关 Pod 正常运行。

## 这次实践里，我现在更在意的事

如果按现在这个思路，我更在意的已经不是“我会不会手动装这些东西”，而是：

### 1）我能不能把部署顺序理清楚

### 2）我能不能把关键步骤收进 Ansible

### 3）我下次重做时，是不是还能复现出来

这三件事比“第一次是否完全手敲成功”更重要。

## 写在最后

现在这个实践被收窄到只有一台服务器以后，反而更适合练自动化。

因为你不用再分心考虑多机协作，也不用把注意力放在环境切换上。

更合理的做法就是：

- 让 Ansible 先接管基础环境
- 再继续接管 k3s
- 再继续接管监控部署
- 最后把日志服务也纳入自动化流程

这样整件事才会真正从“我会手动搭环境”，变成：

> **我已经开始把环境搭建过程整理成一条可以重复执行的自动化路线。**

对现在这个阶段来说，我觉得这比把架构做得很复杂更重要。
