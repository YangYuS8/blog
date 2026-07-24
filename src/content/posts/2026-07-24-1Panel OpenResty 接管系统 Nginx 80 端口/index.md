---
title: "1Panel OpenResty 接管系统 Nginx 80 端口"
urlSlug: '1panel-openresty-take-over-nginx-port-80'
published: 2026-07-24
description: '记录一次 1Panel OpenResty 以 host 网络接管系统 Nginx 80 端口的迁移：先做等价预演，再短窗口切换，并处理面板端口显示不同步的问题。'
image: ''
author: ""
tags: ["1Panel", "OpenResty", "Nginx", "Docker", "systemd", "故障排查", "实战记录"]
category: "云原生与容器"
draft: false
lang: 'zh_CN'
---

这次要解决的目标很明确：把一台 Ubuntu 服务器上由系统包 Nginx 提供的 HTTP 入口，迁移到 1Panel 管理的 OpenResty，同时不能把已有的静态站和 `/data/` 反向代理弄坏。

最终结果是：OpenResty 接管了 `80`，系统 Nginx 保留配置但停止并禁用；从独立网络访问公网映射入口仍返回原页面。过程里还遇到一个容易误判的问题：**面板显示的端口和真实监听端口可以不同步**。这篇记录完整梳理迁移与排查方法。

> 文中的地址、目录和服务名均已做泛化处理；重点是迁移方法、验证顺序与回滚思路。

## 环境

迁移前的入口关系如下：

```text
Internet
  → 路由器公网映射
  → Ubuntu 主机 :80
  → 系统 Nginx
```

主机上已经安装 1Panel，OpenResty 以 Docker 的 host 网络模式运行：

```yaml
network_mode: host
restart: always
```

这意味着 OpenResty 会直接与系统服务竞争宿主机端口。系统 Nginx 已经监听 `80` 时，不能让 OpenResty 也直接改到 `80` 再碰碰运气；正确顺序必须是先预演、再交接。

原 Nginx 中需要保留的语义包括：

- 一个默认静态站点；
- 一个 IP/域名 vhost；
- `client_max_body_size` 和 `client_body_buffer_size`；
- `/data/` 到本机 `127.0.0.1:8008` 的反向代理；
- 自定义错误页和静态根目录。

## 先备份，再看运行态

迁移前先备份生效配置，而不是只复制某个猜测中的 vhost 文件：

```bash
sudo nginx -T > nginx.effective.conf
sudo tar -czf nginx-before-openresty.tar.gz /etc/nginx
sudo sha256sum nginx-before-openresty.tar.gz
sudo tar -tzf nginx-before-openresty.tar.gz >/dev/null
```

这里有两个容易忽略的点：

1. `nginx -T` 才能确认实际加载了哪些文件；
2. 归档创建完成不等于备份可用，至少要校验哈希并跑一次 `tar -tzf`。

然后确认端口归属：

```bash
sudo ss -lntp '( sport = :80 or sport = :443 or sport = :18080 )'
```

迁移前应当看到：

```text
:80     → nginx
:18080  → openresty
:443    → openresty
```

如果已经出现两个相同 `server_name` 的 OpenResty vhost，先停下来。重复 vhost 会产生类似下面的警告：

```text
conflicting server name "..." on 0.0.0.0:18080, ignored
```

这时新配置可能根本没有生效，只是被旧配置遮住了。先备份并移出重复的活动配置，再继续预演。

## 不复制静态文件，使用只读挂载

OpenResty 虽然使用 host 网络，但容器并不能自动读取宿主机的静态目录。最初如果直接改 `root /etc/nginx/html`，容器内通常找不到同一路径。

不要复制一份页面到 OpenResty 的网站目录。那样会制造两份内容来源，回滚和后续维护都会变得混乱。

更稳妥的方式是在 OpenResty 的 Compose 中显式添加只读挂载：

```yaml
volumes:
  - /etc/nginx/html:/srv/legacy-nginx/html:ro
  - /var/www/html:/srv/legacy-default/html:ro
```

然后在 OpenResty vhost 中使用容器内路径：

```nginx
server {
    listen 18080 default_server;
    server_name _;

    root /srv/legacy-default/html;
    index index.html index.htm index.nginx-debian.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

server {
    listen 18080;
    server_name 203.0.113.10;

    client_max_body_size 500m;
    client_body_buffer_size 300m;

    root /srv/legacy-nginx/html;
    index index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    location /data/ {
        proxy_pass http://127.0.0.1:8008/data/;
    }
}
```

因为容器使用的是 host 网络，`127.0.0.1:8008` 仍然指向宿主机的本地上游，不需要凭感觉改成 Docker 网桥地址。

## 在 18080 做等价预演

不要只看 `200`。默认欢迎页同样会返回 `200`，但它没有证明业务 vhost 已经等价。

至少用目标 Host 和未知 Host 分别请求首页和代理路径：

```bash
for host in 203.0.113.10 example.invalid; do
  curl -sS -D - -o /dev/null -H "Host: $host" http://127.0.0.1:18080/
  curl -sS -D - -o /dev/null -H "Host: $host" http://127.0.0.1:18080/data/
done
```

需要比较的不是单一状态码，而是：

- 状态码和 `Content-Type`；
- 静态首页的长度、`ETag` 和正文哈希；
- 默认 vhost 与目标 vhost 的选择是否一致；
- `/data/` 是否仍然到达原来的上游；
- body 限制、错误页、访问控制等业务语义。

对静态页面可以直接比对哈希：

```bash
curl -sS -H 'Host: 203.0.113.10' http://127.0.0.1:80/ | sha256sum
curl -sS -H 'Host: 203.0.113.10' http://127.0.0.1:18080/ | sha256sum
```

动态接口或 JSON 错误页可能含有时间戳、请求 ID 等字段，跨请求正文哈希不同不必立刻判定迁移失败。这里更应该比较状态码、响应类型和长度范围。

预演通过后，再检查 OpenResty：

```bash
docker exec openresty openresty -t
```

## 短窗口交接 80 端口

交接前要保留一个可用 SSH 会话，并准备好回滚顺序。核心原则是：**先释放旧监听，再让新服务绑定，失败就立即反向恢复。**

切换的逻辑可以概括为：

```text
保存 OpenResty 当前配置
→ 将预演 vhost 的 18080 改为 80
→ OpenResty 配置检查
→ 停止系统 Nginx
→ 确认 :80 已释放
→ 重建/启动 OpenResty
→ 本机验证
→ 独立网络验证
```

示例命令：

```bash
sudo systemctl stop nginx
sudo ss -lnt '( sport = :80 )'

sudo docker compose -f /opt/1panel/apps/openresty/openresty/docker-compose.yml \
  up -d --force-recreate --no-deps openresty

sudo docker exec openresty openresty -t
sudo ss -lntp '( sport = :80 )'
```

确认 OpenResty 已取得 `80` 后，再从独立网络请求公网映射入口：

```bash
curl -I -H 'Host: 203.0.113.10' http://203.0.113.10:56793/
```

只有外部路径确认成功，才可以禁用旧 Nginx 的自启动：

```bash
sudo systemctl disable nginx
```

这样下次主机重启后，不会出现系统 Nginx 与 OpenResty 争抢 `80` 的情况。

## 1Panel 显示 18080，但服务实际在 80

切换完成后，我在 1Panel 中仍然看到 HTTP 端口为 `18080`。最开始检查应用 `.env` 和应用资源定义后，它们都已经是 `80`，但 UI 还是没有变化。

最终根因在 1Panel 自己的状态库，而不是浏览器缓存：已安装应用记录保留了安装时的端口。

可以先只读确认：

```sql
SELECT id, name, http_port, https_port, status, container_name
FROM app_installs
WHERE name = 'openresty';
```

如果运行态已经确认在 `80`，而记录仍是 `18080`，应当先备份数据库，再只更新目标应用的唯一记录。不要模糊匹配后批量更新，也不要碰任何凭据字段。

```bash
sudo cp -a /opt/1panel/db/agent.db \
  /root/backup/agent.db.before-openresty-port-sync
```

更新后，只重启 1Panel 管理服务：

```bash
sudo systemctl restart 1panel-core 1panel-agent
```

这两个服务与 Docker/OpenResty 容器处于不同 cgroup。为了避免猜测，我会在重启前后记录 OpenResty 的 PID 和启动时间：

```bash
docker inspect -f '{{.State.StartedAt}} {{.State.Pid}}' openresty
```

如果两者保持不变，就能证明重启面板管理服务没有重启 OpenResty。

## 最终验证清单

本次迁移完成后，至少应确认：

```bash
# OpenResty 配置
sudo docker exec openresty openresty -t

# 端口归属
sudo ss -lntp '( sport = :80 )'

# 旧服务不再启动
systemctl is-active nginx
systemctl is-enabled nginx

# 当前应用记录
sudo sqlite3 /opt/1panel/db/agent.db \
  "SELECT name, http_port, https_port FROM app_installs WHERE name = 'openresty';"
```

预期状态：

```text
:80                  → openresty
nginx.service        → inactive / disabled
OpenResty restart    → always
http_port / https_port → 80 / 443
```

最后仍要从独立网络验证入口。仅在本机看到 `0.0.0.0:80` 不能证明路由器映射、防火墙和上游网络都没问题。

## 回滚顺序

如果 OpenResty 无法稳定接管，先恢复业务，不要继续在线修改：

```text
停止 OpenResty，释放 :80
→ 恢复切换前的 Compose 与 vhost
→ nginx -t
→ 启用并启动系统 Nginx
→ 本机验证
→ 独立网络验证
```

对应命令大致是：

```bash
sudo docker compose -f /opt/1panel/apps/openresty/openresty/docker-compose.yml down
sudo nginx -t
sudo systemctl enable --now nginx
```

旧 Nginx 的配置和归档在确认稳定前都应该保留。迁移不是为了删掉一切旧东西，而是为了在需要时能迅速恢复。

## 总结

这次迁移最重要的不是把 `80` 从一个进程交给另一个进程，而是保证交接前后服务语义没有变化。

可以把关键原则浓缩成四条：

1. 用 `nginx -T` 和 `openresty -T` 确认真实生效配置；
2. 静态目录通过只读挂载复用，不复制页面；
3. 先在备用端口做 Host 级等价验证，再切换生产端口；
4. 面板显示异常时，按“运行态 → 实例配置 → 状态库”的顺序排查，不要只刷新浏览器。
