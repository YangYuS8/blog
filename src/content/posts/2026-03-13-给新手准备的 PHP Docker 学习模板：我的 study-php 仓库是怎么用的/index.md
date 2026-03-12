---
title: "给新手准备的 PHP Docker 学习模板：我的 study-php 仓库是怎么用的"
urlSlug: '20260313-01'
published: 2026-03-13
description: '介绍我做的 study-php 模板仓库：它为什么适合新手、LAMP 和 LNMP 两套环境分别解决什么问题，以及你第一次把它跑起来时应该怎么用。'
image: ''
tags: ["PHP", "Docker", "Docker Compose", "LAMP", "LNMP", "新手向"]
category: '编程实践'
draft: false 
lang: 'zh_CN'
---
最近我把自己平时用来起 PHP 学习环境的东西整理了一下，做成了一个模板仓库：`study-php`。

::github{repo="YangYuS8/study-php"}

我把它开成了 GitHub 模板仓库，所以别人不用先 fork 再清历史，直接点右上角的 `Use this template` 就能生成一份自己的仓库。

我做这个仓库的原因也很直接：很多人学 PHP，还没开始写代码，先被环境劝退了。

如果你不想先在本机手动装 Apache、Nginx、PHP、MySQL、phpMyAdmin 这一套，那这个仓库应该正好能省掉前面那段折腾。

## 这个仓库最适合哪类人

我觉得它比较适合这几种情况：

- 刚开始学 PHP，想先把环境跑起来
- 想练习 PHP + 数据库，但不想先折腾本机服务安装
- 想顺便理解 LAMP 和 LNMP 到底是什么区别
- 想要一个可以随时删掉、重新起的练习环境

它不是业务模板，也不是框架脚手架，就是一个给新手起步用的环境。

## 这个模板仓库里到底放了什么

我把结构尽量压得很简单：

- `src/`：你平时写 PHP 代码的地方
- `nginx/`：只给 LNMP 方案使用的 Nginx 配置
- `docker-compose.lamp.yml`：LAMP 环境启动文件
- `docker-compose.lnmp.yml`：LNMP 环境启动文件
- `php.ini`：PHP 的一些基础配置

你打开之后，基本一眼就知道代码放哪、环境怎么起、文件各自干什么。

## 它提供了两套环境，但代码目录是同一份

仓库里我放了两套可选环境：

- LAMP：Apache + PHP + MariaDB + phpMyAdmin + BrowserSync
- LNMP：Nginx + PHP-FPM + MariaDB + phpMyAdmin + BrowserSync

两套都用同一份 `src/` 代码，区别主要在 Web 服务层：

- 如果你想先少理解一点概念，通常可以先用 LAMP
- 如果你想顺便认识 Nginx + PHP-FPM 这套更常见的拆分方式，可以试 LNMP

我把两套都放进来，主要就是为了方便对比，不用自己重复搭两遍环境。

## LAMP 方案适合先把 PHP 跑起来

LAMP 这套里，用的是 `php:8.3-apache` 镜像。

启动命令：

```bash
docker compose -f docker-compose.lamp.yml up -d
```

启动后，你可以访问：

- 应用页面：`http://localhost:8081`
- BrowserSync：`http://localhost:3000`
- phpMyAdmin：`http://localhost:8082`

如果你只是想先把 PHP 页面跑起来，我会建议先从这个开始。

## LNMP 方案更适合理解现代一点的部署结构

LNMP 这套里，我拆成了 `nginx` 和 `php` 两个服务：

- `nginx:1.27-alpine` 负责接收 HTTP 请求
- `php:8.3-fpm-alpine` 负责执行 PHP

启动命令：

```bash
docker compose -f docker-compose.lnmp.yml up -d
```

启动后访问：

- 应用页面：`http://localhost:8080`
- BrowserSync：`http://localhost:3000`
- phpMyAdmin：`http://localhost:8082`

这套比 LAMP 多一层 Nginx 配置，门槛会高一点，但也更接近很多人后面会碰到的结构。

## 仓库里还额外做了一个对新手很友好的点：实时刷新

所以我在两套 Compose 里都加了 BrowserSync。它会监控这些文件变化：

- `*.php`
- `*.html`
- `*.css`
- `*.js`

你改完 `src/` 里的代码，页面会自动刷新。这个对练习其实挺有用的，至少反馈会快很多。

## 数据库部分也尽量保持简单直白

无论你用 LAMP 还是 LNMP，数据库默认都是 MariaDB，并且配了一套非常直接的默认值：

```txt
host: db
user: root
password: root
database: app
```

另外还带了 phpMyAdmin，方便你可视化查看数据库。

学习阶段我觉得先跑通最重要，后面真要往正式项目走，再慢慢把密码、环境变量这些拆开就行。

## `php.ini` 也做了几个够用的基础设置

这个模板里还放了一个 `php.ini`，做了几项基础设置：

- 开启错误显示：`display_errors=On`
- 错误级别拉满：`error_reporting=E_ALL`
- 时区设为：`Asia/Shanghai`
- 调大常用上传和内存限制

对新手来说，报错能直接看到，排查真的会轻松很多。

## 第一次上手，我建议你按这个顺序来

如果是第一次用，我建议这样走：

### 第一步：先克隆仓库

```bash
git clone https://github.com/YangYuS8/study-php.git
cd study-php
```

如果你想直接拿它当自己的练习项目，也可以不 clone 我的仓库，而是在 GitHub 页面点 `Use this template`，先生成你自己的仓库，再 clone 你自己的那份。

### 第二步：先选 LAMP 跑起来

```bash
docker compose -f docker-compose.lamp.yml up -d
```

### 第三步：打开默认页面确认环境正常

访问 `http://localhost:8081`，你会看到一个很简单的示例页面，上面会显示：

- PHP 已经正常运行
- 当前服务器时间
- 提示你去修改 `src/index.php`

这一步没别的，就是先确认环境通了。

### 第四步：开始修改 `src/index.php`

可以先做几个最基础的实验：

- 输出变量
- 写一个 `if`
- 读 `$_GET`
- 提交一个表单
- 连接数据库试一下查询

### 第五步：再去切换 LNMP 感受区别

等你已经知道这个项目怎么写、怎么跑之后，再试：

```bash
docker compose -f docker-compose.lnmp.yml up -d
```

这样更容易看出两套结构到底差在哪。

## 为什么我觉得这个仓库对新手有价值

我做这个仓库时，脑子里其实就一句话：别让环境安装挡住开始学 PHP 这件事。

很多初学者的问题，并不是不愿意学，而是在真正写第一行业务代码之前，就已经被这些事情消耗掉了：

- 本机服务装不上
- 端口冲突
- PHP 版本不一致
- 数据库工具不会配
- 改完文件还不知道有没有生效

我觉得 Docker Compose 模板最大的价值，就是先把这些重复劳动收起来。

## 这个仓库适合当起点，但不打算替你做完所有决定

我刻意把它做得比较轻，因为学习模板如果封装太多，反而更难看懂。

你后续完全可以在这个基础上继续往上加东西，比如：

- 再补一个 `db/init.sql` 做初始化数据
- 把数据库密码改成 `.env` 管理
- 增加更多 PHP 示例页面
- 再接一个小型登录注册练习
- 后面过渡到 Laravel 或其他框架

所以它更适合当第一步，不是最终形态。

## 如果你刚学 PHP，我会这样使用这个仓库

如果是我自己来用，我会这么走：

- 先用 LAMP，把 PHP 页面跑通
- 先只改 `src/`，不要急着改容器配置
- 先学会连数据库和处理表单
- 再去看 LNMP 和 Nginx 配置
- 等基础稳了，再考虑框架和更正式的工程化拆分

对新手来说，我还是那句话：先稳定开始，比一上来学最完整方案更重要。
