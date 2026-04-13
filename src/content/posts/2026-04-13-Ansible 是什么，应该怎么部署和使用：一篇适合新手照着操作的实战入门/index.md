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

如果你现在已经开始接触多台 Linux 机器，很快就会发现一个现实问题：

**同样的操作，手动做一遍还行，做第二遍、第三遍就开始烦了。**

比如：

- 两台机器都要装同一批软件
- 两台机器都要改同一个配置
- 两台机器都要同步一份文件
- 你不想每次都 SSH 上去一台一台敲命令

这种时候，Ansible 就会开始变得很有价值。

这篇文章我会尽量按“新手真能照着做”的方式来写，而不是只讲概念。

重点会放在：

1. Ansible 到底是干什么的
2. 为什么它比手工 SSH 更适合管理多台机器
3. 该怎么安装
4. 最基础的命令和 playbook 怎么写

## Ansible 是什么

先用一句最简单的话说：

**Ansible 是一个用来批量管理和自动化配置服务器的工具。**

你可以把它理解成：

> 我在一台控制机上写规则，然后让它去别的机器执行。

它很适合做的事情包括：

- 安装软件
- 修改配置文件
- 重启服务
- 创建用户
- 同步文件
- 做初始化部署

## 它和“自己 SSH 上去敲命令”有什么区别

区别不在于“能不能做”，而在于：

- 手工 SSH：临时做事
- Ansible：把做事的方法变成可重复执行的流程

举个很简单的例子。

如果你有两台机器：

- devmint
- zabbix

你想在两台上都安装 `curl`、`git`、`vim`。

手工做法通常是：

```bash
ssh devmint
apt install -y curl git vim

ssh zabbix
apt install -y curl git vim
```

Ansible 的思路则是：

- 先把机器列表写好
- 再用一条命令或一个 playbook 去统一执行

这时候你就会开始发现：

- 重复操作少了
- 不容易漏机器
- 更容易复用
- 以后回头看也知道自己做过什么

## Ansible 为什么很适合新手入门自动化

它比很多人想象中更容易上手，主要因为几个原因：

### 1）通常不需要在目标机器安装复杂 agent

Ansible 最常见的工作方式就是通过 SSH 连过去执行。

也就是说：

- 控制机上装 Ansible
- 目标机上能 SSH 登录
- 通常就能开始用了

### 2）它先从“命令批量执行”开始，再慢慢过渡到 playbook

你不需要第一天就学会很复杂的 role。

你完全可以先学：

- inventory
- ad-hoc 命令
- 最简单的 playbook

### 3）它很适合把“自己已经会手工做的事”自动化

这也是我最推荐的学习方式。

不是为了学 Ansible 才学 Ansible，而是：

- 你本来就要装软件
- 本来就要改配置
- 本来就要重启服务

那就顺手让 Ansible 接管它。

## Ansible 的基本结构

刚开始你只需要记住这三样东西：

### 1. 控制机

也就是你运行 `ansible` 命令的机器。

在你的场景里，通常就是：

- devmint

### 2. 受控主机

也就是 Ansible 要连过去执行操作的目标机器。

例如：

- zabbix
- 其他 Linux 服务器

### 3. inventory

就是主机清单。

你要先告诉 Ansible：

- 哪些机器归它管
- 每台机器地址是什么
- 默认用什么用户登录

## 第一步：在控制机上安装 Ansible

如果你的控制机是 Debian / Ubuntu，最直接的方式是：

```bash
apt update
apt install -y ansible
```

安装好以后先确认版本：

```bash
ansible --version
```

只要能正常输出版本号，说明控制机这一步就已经好了。

## 第二步：确认 SSH 免密登录是通的

Ansible 最顺的前提就是：

**控制机已经能 SSH 免密登录目标机。**

先手工测一下：

```bash
ssh zabbix hostname
```

如果能直接登录并执行命令，那 Ansible 后面会顺很多。

如果这一步都不通，不要急着怪 Ansible，先把 SSH 和密钥登录理顺。

## 第三步：写一份最小 inventory

先建一个工作目录：

```bash
mkdir -p ~/ansible-lab
cd ~/ansible-lab
```

然后建一个 `inventory.ini`：

```ini
[servers]
devmint ansible_host=192.168.3.14 ansible_user=your_user
zabbix ansible_host=192.168.3.20 ansible_user=root
```

如果控制机自己也想被纳入管理，也可以写进去。

你现在最关键的是先理解：

- `devmint` 和 `zabbix` 是 Ansible 自己用的别名
- `ansible_host` 是真实地址
- `ansible_user` 是默认 SSH 用户

## 第四步：先试最基础的连通性

Ansible 最经典的第一条命令就是：

```bash
ansible all -i inventory.ini -m ping
```

注意，这里的 `ping` 不是普通网络里的 ICMP ping，而是 Ansible 自己的测试模块。

如果一切正常，你会看到类似：

```text
zabbix | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

如果这一步失败，先优先检查：

- SSH 是否通
- 用户名是否对
- Python3 是否在目标机上

## 第五步：先学 ad-hoc 命令

很多新手一上来就扑到 playbook，其实没必要。

先学 ad-hoc 命令更容易建立感觉。

### 例如查看主机名

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

### 安装软件（Debian / Ubuntu）

```bash
ansible all -i inventory.ini -b -m apt -a "name=curl state=present update_cache=true"
```

这里：

- `-b` 表示提权执行
- `-m apt` 表示用 apt 模块
- `-a` 后面是模块参数

这一步做完，你就会开始知道：

> Ansible 不是只能写大 playbook，它也可以先拿来做“更高级一点的批量命令执行”。

## 第六步：开始写你的第一个 playbook

当你发现某件事要重复做第二次时，就很适合写成 playbook 了。

### 先写一个最小例子

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

### 运行方式

```bash
ansible-playbook -i inventory.ini bootstrap.yml
```

这个 playbook 做的事情很简单：

- 更新软件源缓存
- 安装一批常用软件

但它已经足够让你理解 playbook 的基本节奏。

## Playbook 里面这几个关键词要先看懂

### `hosts`

表示这份 playbook 要对谁执行。

例如：

```yaml
hosts: servers
```

就是对 inventory 里 `servers` 组里的机器执行。

### `become`

表示要不要提权。

例如：

```yaml
become: true
```

很多安装和配置操作都需要它。

### `tasks`

就是你真正要做的事情列表。

每个 task 都是在描述：

- 做什么
- 用哪个模块
- 参数是什么

## 为什么很多人说 Ansible “幂等”很重要

这是 Ansible 一个特别值得新手尽早理解的特点。

“幂等”说白了就是：

> **你重复执行同一份配置，不应该越跑越乱。**

例如：

- 软件已经装好了，就不要重复乱装
- 用户已经存在了，就不要报错
- 文件已经是目标内容了，就不要重复改动

这就是为什么模块化写法通常比单纯 `shell` 命令更好。

## 新手最常见的几个模块

刚开始先不用学太多，先记这几个就够了：

### `apt`

用于 Debian / Ubuntu 系安装软件。

### `copy`

把文件从控制机拷到目标机。

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

管理服务启动、停止、重启。

例如：

```yaml
- name: Restart nginx
  service:
    name: nginx
    state: restarted
```

### `file`

创建目录、改权限、建软链接都很常用。

## 一个更像真实使用场景的例子

例如你想在 `zabbix` 上：

- 安装 nginx
- 写一个简单首页
- 确保 nginx 启动

可以写成：

```yaml
- hosts: zabbix
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

然后执行：

```bash
ansible-playbook -i inventory.ini nginx.yml
```

这就是一个很完整的小练习了。

## 目录要不要一开始就做得很复杂

我的建议是：不要。

刚开始先用最简单结构就够了，例如：

```text
ansible-lab/
├── inventory.ini
├── bootstrap.yml
└── nginx.yml
```

等你后面真的写多了，再考虑：

- `group_vars`
- `host_vars`
- `roles`
- 更完整的目录结构

新手一开始最容易犯的错，就是还没学会跑，先去学复杂结构。

## 最常见的报错和排查思路

### 1）`UNREACHABLE`

通常优先看：

- SSH 是否通
- 用户名是否对
- 密钥是否可用
- 防火墙是否放行 22

### 2）`python not found`

有些极简系统可能没有 Python3，Ansible 会直接受影响。

可以先在目标机上确认：

```bash
which python3
```

### 3）权限问题

如果提示权限不足，通常就是：

- 少了 `become: true`
- 或当前用户没 sudo 权限

### 4）模块参数写错

这时候最好的办法通常不是瞎猜，而是：

```bash
ansible-doc apt
ansible-doc copy
ansible-doc service
```

Ansible 自带文档其实挺好用。

## 如果你现在想在 devmint 和 zabbix 上练手

我会建议你按这个顺序来：

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
再写一个具体小任务，例如：

- 安装 nginx
- 改首页
- 启动服务

只要你把这四步都跑通，对 Ansible 的理解就已经不再停留在概念层了。

## 写在最后

Ansible 真正好用的地方，不在于它名字听起来有多“运维”，而在于它能把你本来就会手工做的事情，慢慢变成一套能重复执行的流程。

对新手来说，最好的入门方式不是一开始就研究复杂 role，而是：

- 先装起来
- 先把 inventory 写出来
- 先让 `ping` 通
- 先跑几条命令
- 再写一个能看得见效果的小 playbook

只要这一步跨过去了，后面你再去学更复杂的目录结构、变量管理和 role，都会自然得多。
