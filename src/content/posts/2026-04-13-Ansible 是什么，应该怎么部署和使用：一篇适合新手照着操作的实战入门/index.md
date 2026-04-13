---
title: "Ansible 是什么，应该怎么部署和使用：一篇适合新手照着操作的实战入门"
urlSlug: '20260413-03'
published: 2026-04-13
description: '一篇面向新手的 Ansible 入门文章：它到底解决什么问题、为什么会比手工登录更高效，以及如何从安装、inventory、ad-hoc 命令到 playbook 一步步开始使用。'
image: ''
tags: ['Ansible', 'Linux', '自动化', 'DevOps', '运维', '教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

只要开始管理多台 Linux 机器，迟早都会碰到一个很现实的问题：

**同样的操作，手工做一遍还行，做第二遍、第三遍就开始烦了。**

例如：

- 多台机器都要安装同一批软件
- 多台机器都要同步同一个配置
- 多台机器都要重启某个服务
- 不想每次都 SSH 上去一台一台敲命令

这种场景下，Ansible 就会非常顺手。

这篇文章不打算讲太多空泛概念，而是尽量按“新手真的能照着操作”的方式来写。

重点会放在：

1. Ansible 到底是做什么的
2. 为什么它适合管理多台机器
3. 该怎么安装
4. inventory 怎么写
5. ad-hoc 命令怎么用
6. 第一个 playbook 怎么写

## Ansible 是什么

先用一句最简单的话来说：

**Ansible 是一个通过 SSH 批量管理服务器、自动执行配置任务的工具。**

你可以把它理解成：

- 在一台控制机上写好规则
- 然后让它去目标机器执行

它常做的事情包括：

- 安装软件
- 修改配置文件
- 创建用户
- 分发文件
- 重启服务
- 初始化新服务器

## 它和手工 SSH 的区别是什么

区别不在于“能不能做”，而在于：

- 手工 SSH 更适合临时操作
- Ansible 更适合把操作变成可重复执行的流程

举个简单例子。

如果两台机器都要安装：

- `curl`
- `git`
- `vim`

手工做法通常是：

```bash
ssh server-a
apt install -y curl git vim

ssh server-b
apt install -y curl git vim
```

Ansible 的做法则是：

- 先写好目标主机清单
- 再统一执行命令或 playbook

这样会带来几个很直接的好处：

- 不容易漏机器
- 重复劳动减少
- 以后还能重复执行
- 回头看也更容易知道自己做过什么

## 为什么 Ansible 很适合新手入门自动化

对新手来说，Ansible 有个很大的优点：

**上手门槛没有想象中那么高。**

### 1）通常不需要复杂 agent

Ansible 最常见的方式就是：

- 控制机装 Ansible
- 目标机能 SSH 登录
- 然后通过 SSH 执行任务

很多情况下，不需要在每台目标机单独装一套复杂客户端。

### 2）可以先从简单命令开始

你不需要第一天就写复杂 role。

完全可以先从这些开始：

- inventory
- `ansible -m ping`
- ad-hoc 命令
- 最小 playbook

### 3）它特别适合把“已经会手工做的事”自动化

这是最自然的学习方式。

不是为了学 Ansible 才学 Ansible，而是：

- 本来就要装软件
- 本来就要改配置
- 本来就要重启服务

那就顺手让 Ansible 接管它。

## Ansible 的基本结构

刚开始只需要记住三样东西：

### 1. 控制机

就是运行 `ansible` 命令的机器。

### 2. 受控主机

就是 Ansible 要连过去执行操作的目标机器。

### 3. inventory

就是主机清单。

它告诉 Ansible：

- 哪些机器要管理
- 真实地址是什么
- 默认登录用户是谁
- Python 解释器在哪里

## 第一步：在控制机安装 Ansible

如果控制机是 Debian / Ubuntu，最直接的方式通常是：

```bash
apt update
apt install -y ansible
```

安装完先确认版本：

```bash
ansible --version
```

只要版本信息能正常出来，说明控制机这一步就已经完成了。

## 第二步：先确认 SSH 免密登录没问题

Ansible 最顺的前提是：

**控制机已经能通过 SSH 密钥登录到目标机。**

例如先手工测试：

```bash
ssh root@192.168.3.20 hostname
```

如果这一步都不通，那就先不要急着怪 Ansible，应该先把 SSH 和密钥登录理顺。

## 第三步：写一份最小 inventory

先建一个工作目录：

```bash
mkdir -p ~/ansible-lab
cd ~/ansible-lab
```

然后建一个 `inventory.ini`：

```ini
[servers]
server-a ansible_host=192.168.3.20 ansible_user=root ansible_python_interpreter=/usr/bin/python3
server-b ansible_host=your.server.ip ansible_user=root ansible_python_interpreter=/usr/bin/python3
```

这里要先理解几个点：

- `server-a` 和 `server-b` 是 Ansible 自己用的别名
- `ansible_host` 是机器真实地址
- `ansible_user` 是默认登录用户
- `ansible_python_interpreter` 用来明确 Python 路径

如果目标机上的 Python 版本路径不一样，这一项会很有帮助。

## 第四步：先跑最经典的测试命令

Ansible 新手第一条最该会的命令基本就是：

```bash
ansible all -i inventory.ini -m ping
```

注意，这里的 `ping` 不是网络层的 ICMP ping，而是 Ansible 自己的测试模块。

如果配置正常，你会看到类似：

```text
server-a | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

如果这一步失败，优先检查：

- SSH 是否通
- 用户名是否正确
- Python3 是否存在
- 目标机是否允许对应用户登录

## 第五步：先学 ad-hoc 命令

在开始写 playbook 之前，先用 ad-hoc 命令建立感觉会更轻松。

### 查看主机名

```bash
ansible all -i inventory.ini -a "hostname"
```

### 查看磁盘空间

```bash
ansible all -i inventory.ini -a "df -h"
```

### 查看内存

```bash
ansible all -i inventory.ini -a "free -h"
```

### 用 apt 模块装软件

```bash
ansible all -i inventory.ini -b -m apt -a "name=curl state=present update_cache=true"
```

这里：

- `-b` 表示提权执行
- `-m apt` 表示使用 apt 模块
- `-a` 后面是模块参数

这一步做完之后，通常就会对 Ansible 的工作方式有直观感觉了。

## 第六步：开始写第一个 playbook

当某个操作需要重复执行时，就很适合把它写成 playbook。

### 最小例子

新建 `bootstrap.yml`：

```yaml
- hosts: servers
  become: true
  tasks:
    - name: Update apt cache
      apt:
        update_cache: true

    - name: Install common packages
      apt:
        name:
          - curl
          - git
          - vim
          - htop
        state: present
```

### 执行方式

```bash
ansible-playbook -i inventory.ini bootstrap.yml
```

这个 playbook 做的事很简单：

- 更新软件源缓存
- 安装一组常见软件

但它已经足够帮助新手理解 playbook 的基本结构。

## Playbook 里最常见的几个关键词

### `hosts`
表示这份 playbook 要对谁执行。

例如：

```yaml
hosts: servers
```

就是对 inventory 里 `servers` 组的机器执行。

### `become`
表示要不要提权。

例如：

```yaml
become: true
```

很多安装软件、写配置、重启服务的操作都需要它。

### `tasks`
表示真正要执行的任务列表。

每一个 task 都是在描述：

- 做什么
- 用哪个模块
- 参数是什么

## 为什么很多人强调 Ansible 的幂等性

“幂等”这个词一开始听起来有点抽象，但可以先这么理解：

> **同一个 playbook 重复执行，不应该越跑越乱。**

例如：

- 软件已经装好了，就不应该重复乱装
- 文件已经是目标内容了，就不应该每次都改
- 用户已经存在了，就不应该报错

这也是为什么：

- 模块化写法
- 比单纯 `shell` 命令
- 更适合长期维护

## 新手最常用的几个模块

刚开始其实先记住这几个就够了：

### `apt`
用于 Debian / Ubuntu 系安装软件。

### `copy`
把文件从控制机复制到目标机。

例如：

```yaml
- name: Copy config file
  copy:
    src: ./my.conf
    dest: /etc/myapp/my.conf
```

### `template`
和 `copy` 很像，但支持变量渲染。

### `service`
用于启动、停止、重启服务。

例如：

```yaml
- name: Restart nginx
  service:
    name: nginx
    state: restarted
```

### `file`
用来创建目录、修改权限、建软链接。

## 一个更像真实场景的小例子

如果要在某台服务器上：

- 安装 nginx
- 写一个简单首页
- 确保 nginx 正常启动

可以写成：

```yaml
- hosts: server-a
  become: true
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: true

    - name: Write index page
      copy:
        dest: /var/www/html/index.html
        content: "hello from ansible\n"

    - name: Ensure nginx is running
      service:
        name: nginx
        state: started
        enabled: true
```

执行方式：

```bash
ansible-playbook -i inventory.ini nginx.yml
```

这就是一个很完整的小练习。

## 什么时候该开始用 `group_vars` 和 `host_vars`

一开始机器少的时候，很多人会把变量直接写在 inventory 里，这当然能用。

但只要配置一多，就会开始变乱。这时候就该引入：

- `group_vars`
- `host_vars`

### `group_vars` 是做什么的

顾名思义，就是给“一组机器”统一定义变量。

例如你有一个 `servers` 组，就可以写：

```text
ansible-lab/
├── inventory.ini
├── bootstrap.yml
└── group_vars/
    └── servers.yml
```

`group_vars/servers.yml` 里可以放：

```yaml
common_packages:
  - curl
  - git
  - vim
  - htop
```

然后在 playbook 里直接用：

```yaml
- hosts: servers
  become: true
  tasks:
    - name: Install common packages
      apt:
        name: "{{ common_packages }}"
        state: present
        update_cache: true
```

这样你以后如果想改统一的软件包列表，只用改一处。

### `host_vars` 是做什么的

`host_vars` 则是给“某一台机器”单独定义变量。

例如目录结构：

```text
ansible-lab/
├── inventory.ini
├── bootstrap.yml
├── group_vars/
│   └── servers.yml
└── host_vars/
    ├── server-a.yml
    └── server-b.yml
```

例如 `host_vars/server-a.yml`：

```yaml
nginx_server_name: server-a.local
```

`host_vars/server-b.yml`：

```yaml
nginx_server_name: server-b.local
```

这样同一个 playbook 就能根据不同主机自动使用不同变量。

### 什么时候该用它们

我的建议是：

- **变量开始重复**，就考虑 `group_vars`
- **某台机器有特殊值**，就考虑 `host_vars`

### 新手最适合的理解方式

你可以先这样记：

- `inventory`：机器清单
- `group_vars`：一组机器的共享变量
- `host_vars`：单台机器的特殊变量

## 目录要不要一开始就做很复杂

我的建议仍然是：不要。

刚开始先有最基础结构就行，例如：

```text
ansible-lab/
├── inventory.ini
├── bootstrap.yml
├── nginx.yml
├── group_vars/
│   └── servers.yml
└── host_vars/
    └── server-a.yml
```

这已经足够覆盖很多新手场景了。

等你真的写多了，再去引入：

- `roles`
- 更细的目录拆分
- 模板和 handler

刚开始最容易犯的错，就是还没把基本流程跑顺，就先把结构做得太大。

## 最常见的报错和排查方向

### 1）`UNREACHABLE`

优先看：

- SSH 是否通
- 用户名是否对
- 密钥是否正常
- 防火墙是否拦了 SSH

### 2）`python not found`

有些极简系统可能没有 Python3，Ansible 会直接受影响。

可以先在目标机确认：

```bash
which python3
```

### 3）权限问题

如果提示权限不足，通常就是：

- 少了 `become: true`
- 或当前用户没有 sudo 权限

### 4）模块参数写错

这时候最实用的办法通常不是猜，而是直接看模块文档：

```bash
ansible-doc apt
ansible-doc copy
ansible-doc service
```

Ansible 自带文档其实很好用。

## 一条适合新手的练习路线

如果现在想真正把 Ansible 跑起来，可以按这个顺序练：

### 第一步
先让 inventory 跑通：

```bash
ansible all -i inventory.ini -m ping
```

### 第二步
跑几条 ad-hoc 命令：

```bash
ansible all -i inventory.ini -a "hostname"
ansible all -i inventory.ini -a "df -h"
```

### 第三步
写一个最小 bootstrap playbook：

- 安装常用工具
- 更新时间缓存

### 第四步
再写一个具体任务，例如：

- 安装 nginx
- 改首页
- 启动服务

只要把这四步跑顺，对 Ansible 的理解就已经不再是“只会看概念”了。

## 写在最后

Ansible 真正好用的地方，不在于它名字听起来有多“运维”，而在于它能把原本已经会手工做的事情，慢慢变成一套能重复执行的流程。

对新手来说，最好的入门方式不是一上来就研究复杂 role，而是：

- 先装起来
- 先把 inventory 写出来
- 先让 `ping` 通
- 先跑几条命令
- 再写一个能看见效果的小 playbook

只要这一步跨过去了，后面再去学更复杂的目录结构、变量管理和 role，都会自然得多。
