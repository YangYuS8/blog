---
title: "Terraform 是什么，应该怎么部署和使用：一篇适合新手理解 IaC 的入门教程"
urlSlug: '20260413-04'
published: 2026-04-13
description: '一篇面向新手的 Terraform 入门文章：它到底解决什么问题、什么是基础设施即代码、最基础的目录结构、常见命令和使用方式应该怎么理解。'
image: ''
tags: ['Terraform', 'IaC', 'DevOps', 'Linux', '自动化', '教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你已经开始接触 DevOps、云服务器或者自动化，很快就会碰到一个词：

**IaC，Infrastructure as Code，基础设施即代码。**

而只要提到 IaC，Terraform 基本就是绕不过去的工具。

很多人第一次接触 Terraform 时，都会有一种很强的陌生感：

- 它到底是在干什么？
- 我平时不是已经能手动开服务器了吗？
- 为什么还要专门学它？
- 它和 Ansible 又有什么区别？

这篇文章我会尽量从新手最容易理解的角度出发，把 Terraform 讲清楚。

重点会放在：

1. Terraform 到底是什么
2. 它解决了什么问题
3. 应该怎么安装
4. 最基础的目录结构和命令怎么用
5. 新手最适合怎么开始练习

## Terraform 是什么

先用一句最简单的话来说：

**Terraform 是一个用代码来管理基础设施的工具。**

这里的“基础设施”，通常包括：

- 云服务器
- 安全组
- 网络
- 公网 IP
- 子网
- 负载均衡器
- 云厂商上的各种资源

也就是说，Terraform 不是拿来部署应用代码本身的，它更偏向：

> **帮你创建和管理运行环境。**

## 什么叫“基础设施即代码”

这个概念听起来有点大，但其实不难理解。

### 传统做法

很多人一开始是这样管理服务器的：

- 打开云厂商控制台
- 手工点一台 ECS / CVM / EC2
- 手工配安全组
- 手工绑公网 IP
- 手工改配置

这种方式不是不能用，但问题是：

- 容易忘
- 容易配错
- 不能很好复现
- 时间一久自己都说不清当初点了什么

### IaC 的做法

IaC 的思路是：

- 把这些基础设施定义写成代码
- 让工具按代码去创建、更新和销毁资源

Terraform 就是做这件事的典型工具。

所以你可以把它理解成：

- 手工点控制台：靠记忆和鼠标
- Terraform：靠代码和声明式配置

## Terraform 解决的核心问题是什么

Terraform 最大的价值，不是“炫”，而是：

### 1）可复现

你今天创建的环境，只要代码还在，后面就能再创建出一个差不多的版本。

### 2）可追踪

资源是怎么定义的、为什么这样配，都写在文件里。

### 3）可变更

以后如果你想：

- 改实例规格
- 改安全组规则
- 增减资源

就不是靠手动回忆，而是改代码再应用。

### 4）适合协作

当不止一个人维护环境时，代码化会比口头说明和文档截图可靠得多。

## Terraform 和 Ansible 有什么区别

这是新手最容易混淆的问题之一。

先给一个非常粗略但够用的理解：

- **Terraform** 更偏“创建和管理基础设施”
- **Ansible** 更偏“进入服务器后做配置和操作”

例如：

### Terraform 更擅长

- 创建云服务器
- 创建 VPC / 子网
- 配安全组
- 分配公网 IP
- 管理云资源之间的关系

### Ansible 更擅长

- 安装软件
- 改配置文件
- 启动服务
- 分发文件
- 初始化主机环境

所以很多实际项目里，它们是一起用的，而不是互相替代。

## Terraform 的工作方式怎么理解

Terraform 的核心思路其实很朴素：

1. 你写一份配置
2. Terraform 读取配置
3. 它去对比“你想要的状态”和“现在实际的状态”
4. 然后算出差异
5. 再按差异执行变更

这也是为什么很多人会说 Terraform 是“声明式”的。

你不是在告诉它：

- 第一步点哪里
- 第二步按什么按钮
- 第三步等多久

而是在告诉它：

> **我想要一个什么样的最终结果。**

至于中间怎么执行，Terraform 自己负责。

## Terraform 里几个最常见的概念

刚开始学时，先记住这几个词就够了：

### 1. provider

provider 可以理解成：

**Terraform 通过谁去操作资源。**

例如：

- 阿里云 provider
- AWS provider
- 腾讯云 provider
- Docker provider
- Kubernetes provider

没有 provider，Terraform 就不知道该去和谁说话。

### 2. resource

resource 就是你真正想创建或管理的资源。

例如：

- 一台云服务器
- 一条安全组规则
- 一个公网 IP

### 3. variable

variable 就是变量。

用来把一些会变化的值抽出来，例如：

- 地域
- 机器规格
- 镜像 ID
- IP 地址

### 4. output

output 是输出。

例如你创建完服务器后，想把公网 IP 打印出来，就可以用 output。

### 5. state

这也是 Terraform 很重要的一点。

Terraform 会维护一份状态，记录：

- 哪些资源是它创建的
- 当前资源实际是什么样

你可以先把 state 理解成 Terraform 自己的“记忆”。

## 第一步：安装 Terraform

最简单的方法通常是去 HashiCorp 官方页面下载二进制，或者用包管理器安装。

如果你是 Debian / Ubuntu，可以先直接下载官方二进制练手。

### 下载和安装示例

```bash
cd /tmp
wget https://releases.hashicorp.com/terraform/1.11.4/terraform_1.11.4_linux_amd64.zip
unzip terraform_1.11.4_linux_amd64.zip
mv terraform /usr/local/bin/
```

### 验证版本

```bash
terraform version
```

只要版本号能正常出来，说明安装已经成功。

## 第二步：先建一个最小项目目录

新手一开始不用搞太复杂，先从最基础结构开始就够了。

例如：

```text
terraform-lab/
├── main.tf
├── variables.tf
└── outputs.tf
```

很多人刚上来就想把目录拆很细，结果反而容易乱。先让最小结构跑顺更重要。

## 第三步：先看一个最小示例

如果你现在还没有真正操作云资源，也可以先写一个非常简单的 Terraform 结构来熟悉语法。

### `main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
}
```

### `variables.tf`

```hcl
variable "server_ip" {
  type        = string
  description = "Example server IP"
}
```

### `outputs.tf`

```hcl
output "server_ip" {
  value = var.server_ip
}
```

这个例子本身不会创建资源，但它能帮你先理解 Terraform 文件的大致长相。

## Terraform 最常见的几个命令

这是新手最先该记住的部分。

### `terraform init`

初始化项目。

```bash
terraform init
```

它通常会做这些事：

- 初始化工作目录
- 下载 provider
- 准备后续运行环境

一般来说，一个新 Terraform 项目，第一步几乎总是先 `init`。

### `terraform fmt`

格式化配置文件。

```bash
terraform fmt
```

这个命令很简单，但建议养成习惯。

### `terraform validate`

检查配置语法和基本合法性。

```bash
terraform validate
```

它不能保证业务逻辑完全对，但至少能帮你发现很多明显错误。

### `terraform plan`

这是非常重要的一步。

```bash
terraform plan
```

它的作用是：

- 先算出如果应用当前配置，会发生什么
- 告诉你会新增、修改还是删除哪些资源

我很建议新手把它理解成：

> **正式执行前的预演。**

### `terraform apply`

真正执行变更。

```bash
terraform apply
```

通常会让你确认一次。

如果你很明确，也可以：

```bash
terraform apply -auto-approve
```

但新手阶段我其实不太建议养成随手 `-auto-approve` 的习惯。

### `terraform destroy`

销毁当前 Terraform 管理的资源。

```bash
terraform destroy
```

这一步非常有用，但也要小心，因为它是真的会删东西。

## 一个更像真实使用场景的例子

如果你未来真的要管云服务器，Terraform 最常见的使用方式通常是：

- provider 负责连接云厂商 API
- resource 定义服务器和网络资源
- variable 把可变参数抽出来
- output 打印结果

例如，你可能会慢慢写出这样的结构：

```hcl
provider "alicloud" {
  region = var.region
}

resource "alicloud_instance" "main" {
  instance_name = "lab-server"
  instance_type = var.instance_type
  image_id      = var.image_id
}

output "instance_id" {
  value = alicloud_instance.main.id
}
```

即使你现在还没开始真的管云资源，也至少应该先知道 Terraform 的目标就是这样。

## Terraform 和 Ansible 应该怎么配合

这是新手特别容易混乱的一点。

最简单的理解方式是：

- **Terraform 负责把机器和基础设施准备出来**
- **Ansible 负责进入这些机器，把环境和服务配好**

也就是说，它们最自然的配合顺序通常是：

1. Terraform 先创建资源
2. Terraform 输出关键信息，例如公网 IP
3. Ansible 根据这些信息去配置服务器
4. 最后服务真正跑起来

你可以把它理解成：

- Terraform 负责“房子盖好”
- Ansible 负责“房子里面怎么装修和摆家具”

### 一个很常见的真实分工

例如要搭一套实验环境：

#### Terraform 负责
- 创建云服务器
- 绑定公网 IP
- 配安全组
- 配网络相关资源

#### Ansible 负责
- 安装常用软件
- 初始化系统环境
- 安装 Docker / k3s / node_exporter
- 写配置文件
- 启动或重启服务

这两者放在一起，才会变成一条完整链路。

## Terraform 到底必须有云厂商才能用吗

**不必须。**

但如果没有云平台或者其他可被 provider 管理的资源，它的价值通常会下降很多。

Terraform 的核心不是“必须连某个云厂商”，而是：

> **它需要一个可以通过 provider 被声明式管理的对象。**

这个对象可以是：

- 云服务器
- 安全组
- VPC
- Docker 容器
- Kubernetes 资源
- DNS 记录

所以它不是只能管云，但云资源通常是最自然、最容易体现价值的场景。

## 在本地服务器和云服务器场景里，Terraform 该怎么定位

这也是很多人真正开始动手时才会卡住的问题。

### 本地服务器

如果是一台已经存在的本地 Linux 机器，那 Terraform 往往不是主角。

因为这类机器一般不是通过云 API 创建的。

这时候更适合承担主要工作的通常是：

- Ansible
- shell 脚本
- systemd
- Docker / k3s / Helm

换句话说，在本地服务器上：

- Terraform 不是完全不能用
- 但不一定是最先上场、也不一定是最有价值的第一工具

### 云服务器

云服务器则不一样。

因为它背后通常天然就带着：

- 实例
- 安全组
- 公网 IP
- 地域
- 磁盘
- 网络资源

这些都很适合被 Terraform 描述成代码。

所以如果想真正理解 Terraform 的实战价值，最自然的切入口通常是云服务器。

## 一个更贴近实际的落地方式

如果手上同时有：

- 一台本地服务器
- 一台云服务器

那一个很自然的分工方式是：

### 本地服务器更适合做
- k3s
- 监控
- 服务部署练习
- 其他实验环境

### 云服务器更适合做
- Terraform 的练手对象
- 安全组和公网资源管理
- 更接近真实环境的入口资源

这样理解以后，就不会再纠结“为什么我在本地服务器上总觉得 Terraform 用起来不够顺手”，因为它本来就不一定该在本地机上承担最重的职责。

## 一个更接近实践的最小 Terraform 目录

如果想让 Terraform 真正落地，但又不想一上来就堆太复杂，我更建议至少先有这样的结构：

```text
terraform-lab/
├── provider.tf
├── variables.tf
├── main.tf
├── outputs.tf
└── terraform.tfvars
```

### `provider.tf`
放 provider 和 Terraform 自身要求。

### `variables.tf`
放会变化的参数，例如：

- 地域
- 实例名
- 镜像 ID
- 规格

### `terraform.tfvars`
放这些变量的实际值。

### `outputs.tf`
放执行后你想看到的结果，例如实例 ID、公网 IP、实例名。

这种结构一开始就够用了，重点是建立起“资源也应该代码化管理”的思路。

## 新手怎么开始练 Terraform 会更顺

如果现在还是入门阶段，我更建议按下面这个节奏来：

### 第一步：先装好 Terraform

先确认：

```bash
terraform version
```

没问题。

### 第二步：先建立最小目录

哪怕只有：

- `main.tf`
- `variables.tf`
- `outputs.tf`

也够。

### 第三步：先把命令节奏跑顺

至少把这些命令都自己跑过一遍：

```bash
terraform init
terraform fmt
terraform validate
terraform plan
```

### 第四步：再开始接真实 provider

不要一上来就把“连云厂商、建实例、建网络、建一堆资源”全堆上去。

先把目录结构和命令理解清楚，再接真实资源会轻松很多。

## Terraform 状态文件为什么要小心

Terraform 在执行过程中会生成状态文件，一般是：

```text
terraform.tfstate
```

这个文件非常重要，因为 Terraform 通过它记录当前资源状态。

所以至少要记住这几点：

- 不要随便手改
- 不要乱删
- 不要把敏感内容随便公开出去

对新手来说，先把它理解成 Terraform 的“状态记忆文件”就够了。

## 新手最常见的误区

### 1）把 Terraform 当成部署应用代码的工具

Terraform 更适合管基础设施，而不是替代应用部署本身。

### 2）不看 `plan` 就直接 `apply`

这非常容易出问题。

### 3）一开始就追求复杂目录结构

其实没必要，先让最小结构跑起来更重要。

### 4）把 Terraform 和 Ansible 混成一件事

它们能协作，但职责最好分清楚。

## 如果把它用于实践任务，应该怎么定目标

如果你现在正准备做综合实践，我会建议把 Terraform 的目标先定成：

- 体现 IaC 思路
- 形成清楚的目录结构
- 能跑通基础命令
- 能解释清楚它在整套流程里负责什么

如果服务器已经提前准备好了，那 Terraform 在这次任务里不一定非要承担最重的资源创建职责，但你至少要把它的角色理解准确。

## 写在最后

Terraform 最值得学的地方，不只是某几个命令，而是它会逼着你开始用“目标状态”的方式去思考基础设施。

一开始不用追求太大，先把：

- 目录结构
- provider / resource / variable / output
- `init` / `validate` / `plan` / `apply`

这些基本功跑顺，就已经很够用了。

后面再把它和 Ansible 串起来，你对“基础设施”和“配置管理”之间的边界也会清楚很多。