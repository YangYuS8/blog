---
title: "我准备怎么用两台服务器做完一次运维实践任务：从环境准备到监控与日志的落地路线"
urlSlug: '20260413-02'
published: 2026-04-13
description: '一篇偏实践记录风格的文章：当我手上有一台本地服务器和一台公网云服务器时，怎样以 Ansible 为主线，把环境初始化、k3s、Prometheus、Grafana 和日志服务一步步自动化落地。'
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

不过现在我更确定一件事：

> **这次实践不应该再写成“先手工全部做一遍”，而应该尽量让 Ansible 尽早接管。**

因为如果 Ansible 只拿来装几个基础包，那它在整套任务里的价值其实并没有真正发挥出来。

所以这篇文章，我会按一个更贴近当前目标的思路来写：

- 两台机器怎么分工
- Ansible 怎么组织目录
- 哪些事情交给 Ansible
- 怎样让 k3s、Prometheus、Grafana 也进入自动化流程
- 日志服务怎么放到整套路线里

## 先把目标说清楚

这次实践，我不会追求把环境搭成真正的生产架构，而是追求：

**做出一套两台机器协作、并且能够重复执行的最小自动化版本。**

也就是说：

- 本地服务器 `k3s` 负责跑 Kubernetes 实验环境
- 公网云服务器负责承担更适合公网访问和远程管理的角色
- Ansible 负责把环境初始化、k3s、Helm、Prometheus、Grafana 这些步骤串起来
- ELK 先按最小实验版本去落地

这样做的重点不是“炫技”，而是：

- 以后重做时不需要从头手敲
- 同样的步骤可以反复执行
- 环境结构和部署顺序能沉淀下来

## 这两台机器我准备怎么分工

### 本地服务器：`k3s`
我准备用来做：

- k3s 单节点集群
- Helm 部署练习
- Prometheus + Grafana 的 Kubernetes 内部署
- 一部分实验性服务

### 公网云服务器：`cloud-vps`
我准备用来做：

- 对外可访问的远程入口
- 日志相关的辅助服务
- 一部分更接近真实环境的服务练习

这么分工的原因很简单：

- k3s 放本地更灵活
- 公网机器不需要承受全部实验负载
- 两台机器角色分清楚以后，Ansible 也更容易分组管理

## 第一步：先把 SSH 管理理顺

因为后面所有自动化都要建立在 SSH 能稳定连接的基础上，所以这一步不能省。

先在管理机上准备 `~/.ssh/config`：

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

然后先手工确认：

```bash
ssh k3s hostname
ssh cloud-vps hostname
```

如果这一步都不顺，后面不要急着怪 Ansible，应该先把 SSH 打通。

## 第二步：先搭一个最小的 Ansible 目录

我会先建一个自己的工作目录：

```bash
mkdir -p ~/lab-ops/ansible/{group_vars,host_vars,playbooks}
cd ~/lab-ops/ansible
```

这次我不想只写一个 `bootstrap.yml` 就结束，而是准备从一开始就按后续能扩展的方式组织。

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

## 第三步：把 inventory 先写清楚

```ini
[local]
k3s ansible_host=192.168.3.5 ansible_user=root

[cloud]
cloud-vps ansible_host=your.server.ip ansible_user=root

[k3s_nodes]
k3s

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

这样分组以后，后面就能很自然地写：

- `hosts: all`
- `hosts: k3s_nodes`
- `hosts: cloud`

## 第四步：先用 Ansible 做基础初始化

先做最基础的一层，目的是把两台机器都整理到可继续自动化的状态。

### `playbooks/bootstrap.yml`

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
          - ca-certificates
        state: present
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/bootstrap.yml
```

这一层做完以后，两台机器至少先有一个统一起点。

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

    - name: Check node status
      shell: kubectl get nodes
      register: k3s_nodes_result
      changed_when: false

    - name: Show node status
      debug:
        var: k3s_nodes_result.stdout_lines
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/k3s.yml
```

这里的重点不是把 `curl | sh` 包了一层，而是：

- 以后重装时可以重复跑
- k3s 安装被纳入了统一流程
- 至少已经从“手工部署”进入“可重复执行”

## 第六步：再让 Ansible 接管 Helm

既然后面 Prometheus 和 Grafana 都要通过 Helm 安装，那 Helm 也应该进入自动化流程。

可以直接接在 `k3s.yml` 里，也可以单独拆一个 playbook。

例如先写进 `k3s.yml`：

```yaml
    - name: Install Helm
      shell: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      args:
        creates: /usr/local/bin/helm
```

执行完以后，可以手工确认：

```bash
ssh k3s helm version
```

## 第七步：把 Prometheus + Grafana 也收进 Ansible

如果这一步还继续手工装，那前面 Ansible 的价值就还是没有完全发挥出来。

所以我会直接把监控也写成 playbook。

### `playbooks/monitoring.yml`

```yaml
- hosts: k3s_nodes
  become: true
  tasks:
    - name: Add Prometheus Helm repo
      shell: helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
      changed_when: false

    - name: Update Helm repos
      shell: helm repo update
      changed_when: false

    - name: Create monitoring namespace
      shell: kubectl create namespace monitoring
      register: monitoring_ns
      failed_when: monitoring_ns.rc != 0 and 'already exists' not in monitoring_ns.stderr
      changed_when: "'created' in monitoring_ns.stdout"

    - name: Install kube-prometheus-stack
      shell: helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/monitoring.yml
```

### 部署后怎么确认

```bash
ssh k3s kubectl get pods -n monitoring
ssh k3s kubectl get svc -n monitoring
```

如果只是临时访问 Grafana，依然可以端口转发：

```bash
ssh k3s kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

浏览器访问：

```text
http://127.0.0.1:3000
```

## 第八步：日志服务怎么放进这条自动化路线

ELK 这部分我还是会放到后面，因为它通常更重，也更容易拖慢节奏。

但如果要让整套实践更完整，我还是会把它纳入 Ansible，而不是继续完全手工。

### 一个比较现实的做法

先把 ELK 放到云服务器，用 Docker 做最小实验。

### `playbooks/logging.yml`

```yaml
- hosts: cloud
  become: true
  tasks:
    - name: Install Docker
      apt:
        name: docker.io
        state: present
        update_cache: true

    - name: Ensure Docker service is running
      service:
        name: docker
        state: started
        enabled: true

    - name: Run Elasticsearch container
      shell: |
        docker rm -f elasticsearch || true
        docker run -d --name elasticsearch \
          -p 9200:9200 \
          -e discovery.type=single-node \
          -e xpack.security.enabled=false \
          docker.elastic.co/elasticsearch/elasticsearch:8.13.4

    - name: Run Kibana container
      shell: |
        docker rm -f kibana || true
        docker run -d --name kibana \
          -p 5601:5601 \
          -e ELASTICSEARCH_HOSTS=http://127.0.0.1:9200 \
          docker.elastic.co/kibana/kibana:8.13.4
```

### 执行方式

```bash
ansible-playbook -i inventory.ini playbooks/logging.yml
```

这里我没有一上来就追求特别漂亮的 role 结构，因为现在最重要的是先把整条自动化路线跑起来。

## 第九步：这一套自动化路线到底长什么样

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
- ELK 最小实验已经跑起来

这时候你再回头看，就会发现 Ansible 已经不只是“装几个包”，而是真的在承担整套部署流程的主线角色。

## 第十步：怎么验收这次实践

如果做到后面没有一个明确验收表，很容易出现一种情况：

- 每个步骤都做了一点
- 但自己也说不清到底算不算完成

所以我会给自己列最小验收项。

### 基础连接

```bash
ssh k3s hostname
ssh cloud-vps hostname
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
ssh cloud-vps docker ps
ssh cloud-vps curl http://127.0.0.1:9200
```

至少 Elasticsearch 正常返回。

## 这次实践里，我现在更在意的事

如果按现在这个思路，我更在意的已经不是“我会不会手动装这些东西”，而是：

### 1）我能不能把部署顺序理清楚

### 2）我能不能把关键步骤收进 Ansible

### 3）我下次重做时，是不是还能复现出来

这三件事比“第一次是否完全手敲成功”更重要。

## 写在最后

如果只把 Ansible 用在系统初始化，那它在这套任务里的作用其实还太保守。

更合理的做法应该是：

- 让它先接管基础环境
- 再继续接管 k3s
- 再继续接管监控部署
- 最后把日志服务也纳入自动化流程

这样整件事才会真正从“我会手动搭环境”，变成：

> **我已经开始把环境搭建过程整理成一条可以重复执行的自动化路线。**

对这次实践来说，我觉得这才是更有价值的成果。
