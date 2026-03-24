---
title: "Zabbix server 在 Docker、agent2 在宿主机时，为什么会报 Zabbix agent is not available"
urlSlug: '20260324-01'
published: 2026-03-24
description: '记录一次 Zabbix 可用性问题排查：前端正常、Agent2 正常监听，但监测页仍然提示 “Zabbix agent is not available”。最终定位到 Docker 容器与宿主机 Agent2 的访问控制配置不匹配。'
image: ''
tags: ['Zabbix', 'Docker', 'Linux', '运维', '故障排查']
category: '运维实践'
draft: false 
lang: 'zh_CN'
---

今天排了一个很典型的 Zabbix 问题，现象不复杂，但很容易被误判。

场景是这样的：

- Zabbix Web 前端运行在 `100.64.0.10:8080`
- `zabbix-server` 跑在 Docker 容器里
- `zabbix-agent2` 跑在宿主机本体上
- 前端可以正常打开，也能正常登录
- 但在“监测 → 问题”页面里，`Zabbix server` 这台主机一直有一条 **一般严重** 的告警：

```text
Linux: Zabbix agent is not available (for 3m)
```

这篇文章就记录一下这次排查过程，以及最后为什么问题其实不在 Web、不在数据库，也不在 agent2 本身有没有启动，而是在 **Docker 容器与宿主机 agent2 的访问关系** 上。

## 先确认：不是前端挂了，也不是账号问题

第一步我先做的是最基本的验证：

- `8080` 端口通不通
- Zabbix 登录页能不能打开
- 默认管理员账号能不能登录

结果很明确：

- `http://100.64.0.10:8080` 返回 `200 OK`
- 登录页正常
- 登录后能进入仪表盘
- 前端标题显示 `Zabbix docker: 仪表盘`

这一步很重要，因为它先排除了两类常见误判：

1. 以为是 Zabbix 整体服务挂了
2. 以为是前端 PHP / 数据库连接有问题

至少从这一层看，Web 前端是健康的。

## 问题页里到底是哪条告警

继续往“监测 → 问题”里看，最后锁定到的触发器是：

- **主机**：`Zabbix server`
- **严重性**：`一般严重`
- **问题名**：`Linux: Zabbix agent is not available (for 3m)`
- **triggerid**：`22391`

这条告警的含义其实很直接：

> Zabbix server 无法通过 agent 接口正常获取这台主机的数据，持续超过了 3 分钟。

也就是说，问题已经缩小到：

- 不是 Zabbix Web
- 而是 **Zabbix server 到 agent2 的检查链路**

## 先看 agent2 自己有没有真的起来

因为 agent2 跑在宿主机上，所以我先确认两件事：

1. 服务在不在
2. 10050 端口开没开

检查结果：

```bash
systemctl status zabbix-agent2
ss -lntp | grep 10050
```

结果都正常：

- `zabbix-agent2` 是 `active (running)`
- `*:10050` 正在监听

这说明问题不是：

- agent2 没启动
- agent2 根本没监听端口

如果只停在这里，很容易会觉得“那它明明没问题”。但这种判断还不够，因为这里验证的只是：

> **宿主机上的 agent2 在本机视角是活的**

还没验证：

> **Docker 里的 zabbix-server 能不能访问它**

## 关键点：宿主机能通，不代表容器也能通

因为 `zabbix-server` 是跑在 Docker 里的，所以接下来要看的不是“我能不能从外部连到 10050”，而是：

> **Zabbix server 容器访问宿主机 agent2 时，agent2 会不会接受这个来源。**

继续看 agent2 配置：

```ini
Server=127.0.0.1
ServerActive=127.0.0.1:10051
Hostname=Zabbix server
```

这几行配置一出来，问题其实已经很接近答案了。

### 为什么这里有问题

`Server=` 的含义不是“agent 去连谁”，而是：

> **哪些 Zabbix server / proxy 被允许来请求这个 agent**

而当时这台机器上的配置写的是：

```ini
Server=127.0.0.1
```

也就是说：

- 只有 `127.0.0.1` 被允许访问这个 agent
- 但 `zabbix-server` 并不在宿主机本体上
- 它跑在 Docker 容器里

所以还需要继续看 `zabbix-server` 容器的实际来源地址。

## 查 Docker 容器 IP，问题彻底坐实

接下来我查了容器情况：

```bash
docker ps
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}} {{end}}' zabbix-server
```

结果里，`zabbix-server` 容器的 IP 是：

```text
172.18.0.4
```

到这里，整个问题链路就很清楚了：

- `zabbix-server` 容器来源 IP：`172.18.0.4`
- `zabbix-agent2` 只允许：`127.0.0.1`
- 所以 server 发起的被动检查会被 agent2 拒绝
- 最终触发：

```text
Linux: Zabbix agent is not available (for 3m)
```

这也是这类问题最容易踩的地方：

> 从宿主机本地看，agent2 明明是正常的；但真正访问它的其实是容器，而不是宿主机上的 localhost。

## 修复方式

最直接的修法，是先把当前容器 IP 放进 `Server=`：

```ini
Server=127.0.0.1,172.18.0.4
```

改完后重启 agent2：

```bash
systemctl restart zabbix-agent2
```

这样可以立刻恢复。

但是这种写法不够稳，因为 Docker 容器 IP 以后可能会变。

所以最后我把它改成了更合适的网段方式：

```ini
Server=127.0.0.1,172.18.0.0/16
ServerActive=127.0.0.1:10051
Hostname=Zabbix server
```

然后再次重启：

```bash
systemctl restart zabbix-agent2
```

这样做的好处是：

- 当前容器 `172.18.0.4` 可以访问
- 以后容器重建后 IP 变了，只要还在这个 Docker 网段里，也不会因为同样原因再次告警

## 为什么 `ServerActive` 不需要一起改

这里顺手解释一下，避免混淆。

当前配置里：

```ini
ServerActive=127.0.0.1:10051
```

这项控制的是：

> agent 主动模式上报时，要把数据发到哪里

而这次出问题的告警是：

```text
Zabbix agent is not available
```

它本质上对应的是 **被动检查** 失败，所以更关键的是：

```ini
Server=
```

不是 `ServerActive=`。

也就是说，这次故障的根因不在主动模式链路，而在：

- `zabbix-server` 容器向宿主机 agent2 发起被动请求时，没有被允许

## 这类场景以后怎么快速判断

如果后面我再遇到类似场景：

- Zabbix server 在 Docker 里
- agent / agent2 在宿主机上
- 前端正常但 host availability 报错

我会优先按这个顺序排：

### 1. 先确认是不是 Web 问题

- 前端能不能打开
- 能不能登录
- 问题页面能不能看到具体触发器

### 2. 再确认 agent 服务本身是不是活着

```bash
systemctl status zabbix-agent2
ss -lntp | grep 10050
```

### 3. 看 agent2 配置里的 `Server=`

```bash
grep -E '^(Server|ServerActive|Hostname)=' /etc/zabbix/zabbix_agent2.conf
```

### 4. 查 server 容器的实际来源 IP

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}} {{end}}' zabbix-server
```

### 5. 对照看 `Server=` 是否放行了这个来源

如果没放行，那就别继续怀疑数据库、前端或者模板了，先把访问控制修正。

## 最后的结论

这次问题的根因可以压成一句话：

> **Zabbix server 跑在 Docker 容器里，但宿主机上的 agent2 只允许 `127.0.0.1` 访问，导致 server 容器无法完成被动检查。**

修复的关键就是把 `Server=` 从“只允许 localhost”改成“允许 Docker 容器来源”。

最终稳定方案是：

```ini
Server=127.0.0.1,172.18.0.0/16
```

然后重启 `zabbix-agent2`。

这类问题表面上看像是“agent 挂了”，其实很多时候只是：

**容器网络视角和宿主机本地视角，不是同一个世界。**
