---
title: "Prometheus + Grafana 实战入门：从一台 Linux 服务器开始搭自己的监控面板"
urlSlug: '20260412-04'
published: 2026-04-12
description: '一篇偏实战的 Prometheus + Grafana 入门教程：从 node_exporter 开始，到 Prometheus 抓指标，再到 Grafana 出图，尽量按新手可以照着做的顺序来写。'
image: ''
tags: ['Prometheus', 'Grafana', '监控', 'Linux', 'DevOps', '实战教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

前面如果你已经大概知道了：

- Prometheus 是用来采集和查询指标的
- Grafana 是用来把指标画成图的

那下一步最自然的问题就是：

**我到底怎么把它们真的跑起来？**

这篇文章我不准备讲得太虚，我会按“你现在就想在一台 Linux 服务器上动手搭起来”的思路来写。

目标很简单：

- 让 Prometheus 抓到一台 Linux 主机的指标
- 再让 Grafana 把这些指标显示出来

如果你想在自己的服务器上练手，这篇会比较适合直接照着做。

## 这篇文章要做的事

我们先只做最基础的一条链路：

- 一台 Linux 服务器
- `node_exporter`
- `Prometheus`
- `Grafana`

这里我默认你手上已经有一台 Linux 机器，比如：

- Debian / Ubuntu
- CentOS / Rocky / AlmaLinux
- Arch / CachyOS
- 或者一台 VPS / 家里的 Linux 虚拟机

## 先理解一下这三者的关系

在真正开始之前，先把关系捋顺，不然后面很容易边装边乱。

### `node_exporter`
负责把系统指标暴露出来。

比如：

- CPU
- 内存
- 磁盘
- 网络
- load

### Prometheus
负责定时去抓 `node_exporter` 提供的指标，然后存成时间序列。

### Grafana
负责把 Prometheus 里的数据画成图表。

你可以先把它们理解成这样：

- `node_exporter`：指标提供者
- Prometheus：指标仓库
- Grafana：指标展示层

## 第一步：在目标服务器上部署 `node_exporter`

这是最基础的一步。

如果你只想先搭出最小监控闭环，那 `node_exporter` 基本就是最好的起点。

### 下载并解压

以 Linux x86_64 为例：

```bash
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-1.9.1.linux-amd64.tar.gz
tar -xzf node_exporter-1.9.1.linux-amd64.tar.gz
cd node_exporter-1.9.1.linux-amd64
```

版本号以后可能会变，你可以去 GitHub Releases 页面看最新版本。

### 直接运行测试

```bash
./node_exporter
```

默认它会监听：

```text
0.0.0.0:9100
```

这时候你可以在服务器本机测试：

```bash
curl http://127.0.0.1:9100/metrics | head
```

如果能看到一堆以 `node_` 开头的指标，说明它已经正常工作了。

## 第二步：把 `node_exporter` 做成 systemd 服务

如果只是临时试试，前面那一步就够了。

但如果你想长期用，最好还是做成 systemd 服务。

### 创建用户

```bash
useradd --no-create-home --shell /usr/sbin/nologin node_exporter
```

### 移动二进制文件

```bash
cp ./node_exporter /usr/local/bin/node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

### 写 systemd 服务文件

创建：

```bash
/etc/systemd/system/node_exporter.service
```

内容例如：

```ini
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 启动并设置开机自启

```bash
systemctl daemon-reload
systemctl enable --now node_exporter
systemctl status node_exporter --no-pager
```

如果状态是 `active (running)`，说明这一步已经完成。

## 第三步：部署 Prometheus

Prometheus 可以装在同一台机器，也可以装在另一台机器。

如果你只是练手，最简单的方式就是先装在同一台机器上。

### 下载并解压

```bash
cd /tmp
wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-3.4.0.linux-amd64.tar.gz
tar -xzf prometheus-3.4.0.linux-amd64.tar.gz
cd prometheus-3.4.0.linux-amd64
```

### 最小配置文件

编辑 `prometheus.yml`，核心内容类似这样：

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['127.0.0.1:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['127.0.0.1:9100']
```

意思其实很直白：

- Prometheus 也监控自己
- Prometheus 去抓本机的 `node_exporter`

### 直接运行测试

```bash
./prometheus --config.file=prometheus.yml
```

然后访问：

```text
http://你的服务器IP:9090
```

如果能打开 Prometheus 界面，说明它已经起来了。

### 先查一个最基础的指标

在 Prometheus 页面里查：

```text
up
```

如果你看到：

- Prometheus 自己是 `1`
- `node` 这个 target 也是 `1`

说明采集链路已经通了。

## 第四步：把 Prometheus 也做成服务

和 `node_exporter` 一样，临时运行可以先试，但正式用最好还是交给 systemd。

这一步和前面很像：

- 创建专门用户
- 放到固定目录
- 写 systemd 文件

这里我不把 systemd 文件再写得太长，核心逻辑和 `node_exporter` 一样，你只要记住 Prometheus 的二进制、配置文件、数据目录这三件事要对应好就行。

如果你是第一次练手，甚至可以先不急着把这一步做得很正式，先把 Grafana 接上去再说。

## 第五步：部署 Grafana

Grafana 的安装方式很多。

对 Debian / Ubuntu 来说，最常见的是用官方仓库安装。

### Debian / Ubuntu 示例

```bash
apt-get install -y adduser libfontconfig1 musl
wget https://dl.grafana.com/enterprise/release/grafana-enterprise_11.1.0_amd64.deb
apt-get install -y ./grafana-enterprise_11.1.0_amd64.deb
```

装完以后启动：

```bash
systemctl enable --now grafana-server
systemctl status grafana-server --no-pager
```

默认端口通常是：

```text
3000
```

然后访问：

```text
http://你的服务器IP:3000
```

第一次登录默认账号一般是：

- 用户名：`admin`
- 密码：`admin`

登录后它通常会要求你修改密码。

## 第六步：在 Grafana 里添加 Prometheus 数据源

进入 Grafana 后，基本流程是：

1. 打开 Data Sources
2. 选择 Prometheus
3. 填 Prometheus 地址

如果 Grafana 和 Prometheus 在同一台机器，通常可以填：

```text
http://127.0.0.1:9090
```

保存并测试。

如果显示连接成功，说明：

- Grafana 已经能读到 Prometheus
- 下一步就可以做 dashboard 了

## 第七步：导入一个现成的 Node Exporter Dashboard

这是我最推荐新手做的事。

不要一开始就自己手搓面板。

先导入一个成熟模板，你会更快进入状态。

Grafana 社区里有很多现成 dashboard，最常见的就是 Node Exporter 主机监控模板。

你可以在 Grafana 官方 dashboard 网站搜：

- `Node Exporter Full`

导入后选中你的 Prometheus 数据源，Grafana 就会自动把这些图表和数据对应起来。

这时候你通常就能看到：

- CPU
- 内存
- 磁盘
- 网络流量
- load average
- 文件系统使用率

都开始正常显示了。

## 到这一步，你其实已经完成了第一套监控闭环

链路就是：

- `node_exporter` 暴露主机指标
- Prometheus 抓这些指标
- Grafana 把它们画出来

对新手来说，这已经是一个很完整、而且很有成就感的起点了。

## 你接下来最适合做的几件事

如果你已经把这套东西跑起来了，下一步可以继续做这些：

### 1）熟悉几个基础指标

例如：

- `up`
- `node_cpu_seconds_total`
- `node_memory_MemAvailable_bytes`
- `node_filesystem_avail_bytes`
- `node_load1`

### 2）观察一天的趋势

不要只盯着刚部署成功那一刻。

更有价值的是：

- 白天和晚上有什么差异
- 某个服务启动时资源变化如何
- 磁盘是不是一直在慢慢变满

### 3）试着自己加一个 Panel

哪怕只是：

- 复制一个现有图表
- 改一个查询
- 改个标题

这个过程都会帮助你更快理解 Grafana 和 Prometheus 的关系。

## 新手最常见的坑

### 坑 1：Prometheus 能起来，但抓不到 node_exporter

这种情况一般先查：

- `node_exporter` 是否真的在监听 9100
- Prometheus 配置里的 target 写得对不对
- 防火墙有没有拦

### 坑 2：Grafana 能打开，但看不到数据

这时候优先检查：

- Prometheus 数据源是否添加成功
- Prometheus 里 `up` 是否正常
- Dashboard 绑定的是不是正确的数据源

### 坑 3：第一次看到很多图，但不知道看什么

这是正常的。

刚开始不用想“我要做很厉害的监控分析”，你只要先看懂：

- CPU 有没有异常波动
- 内存是不是稳定上升
- 磁盘是不是在持续减少

这就已经很有用了。

## 如果你现在想在 zabbix 这台机器上练手

那我会建议你按这个顺序做：

1. 先部署 `node_exporter`
2. 再部署 Prometheus
3. 确认 `up` 能查到
4. 再装 Grafana
5. 导入一个 Node Exporter Dashboard

先别急着监控太多服务。

只要把“主机监控”这一条链路跑顺，你后面再监控 Docker、Nginx、MySQL、PostgreSQL，都只是继续往上加东西。

## 写在最后

Prometheus + Grafana 这套东西，第一次接触时确实容易觉得名字很多、组件很多。

但如果你把它拆开看，就会发现其实并不复杂：

- `node_exporter` 负责提供指标
- Prometheus 负责抓和存
- Grafana 负责画图

对新手来说，最重要的不是一下子学全，而是先把第一套闭环搭出来。

只要你能在一台机器上看到：

- CPU 曲线
- 内存曲线
- 磁盘曲线

那你对监控体系的理解就已经不再停留在概念层了。

这一步一旦走通，后面学告警、学 PromQL、学更多 exporter，都会容易很多。
