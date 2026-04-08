---
title: "一晚把 OpenClaw 修顺：从 Telegram 扩展缺文件到 gateway 真正恢复"
urlSlug: '20260408-01'
published: 2026-04-08
description: '记录一次把 OpenClaw 从异常状态修回正常的过程：Telegram 扩展加载缺文件、gateway service 残留旧版本、GEMINI_API_KEY 没进 systemd 环境，最后把整条链路理顺。'
image: ''
tags: ['OpenClaw', 'Telegram', 'systemd', 'gateway', 'Gemini', 'Linux']
category: '问题排查'
draft: false 
lang: 'zh_CN'
---

这晚最开始，我只是想把 OpenClaw 重新拉回可用状态。

结果越修越深，最后发现问题不是一个点，而是三层叠在一起：

- 2026.4.7 版本里 Telegram 扩展加载路径坏了
- gateway service 还残留着旧版本入口
- 修完之后，`GEMINI_API_KEY` 又没进 systemd 环境

也就是说，它不是“一个报错”，而是一串彼此咬住的报错。

## 先爆出来的是 Telegram 扩展缺文件

最先看到的核心报错很直接：

```text
ENOENT: no such file or directory ... dist/extensions/telegram/src/channel.setup.js
```

这句话的意思其实很简单，OpenClaw 想加载 Telegram 内置扩展，但它要找的 `channel.setup.js` 根本不存在。

我顺着看了 2026.4.7 的安装内容，发现 `telegram` 目录里只有 `setup-entry.js`，没有它自己引用的那个 `src/channel.setup.js`。这就不是配置写错，而是**包内容和加载逻辑对不上**。

所以这一步我基本可以判断：

- 不是 Telegram 配置问题
- 不是 token 问题
- 是 2026.4.7 这份安装包本身就有坑

## 旧版本还没彻底退干净

更烦的是，系统里不是只有一份 OpenClaw。

我全局安装已经到了 `2026.4.7`，但 `openclaw-gateway.service` 里还在指向 `2026.3.24` 的旧路径。

这就会导致一个很别扭的现象：

- 你手动跑主程序，撞上新版本 Telegram 扩展缺文件
- 你让 systemd 自动拉 gateway，又撞上旧版本 `ExecStart` 路径失效

结果就是两边一起炸，日志里还会出现 `203/EXEC`。

这个错误本质上很像：

> 服务文件还没更新，但程序已经换版本了。

## 我先做的处理是回退

既然 2026.4.7 这份包本身有问题，我就先退回到之前相对正常的版本。

这个选择其实不花哨，但最稳。

原因很简单，修 service 再修配置，都没用，前提是程序包得先是好的。

所以我先把旧服务停掉，再卸载，再回退版本，然后重新让 gateway service 对齐当前安装。

## 修完主程序后，新的坑出现在 systemd 环境里

等 OpenClaw 主程序和 gateway 路径终于对上了，新的问题又冒出来：

```text
GEMINI_API_KEY not found
```

这次不是程序坏，而是 **systemd user service 没吃到我 shell 里的环境变量**。

我本地 shell 里明明有 `GEMINI_API_KEY`，但 gateway 是 systemd 拉起来的，它看的是自己的环境，不是我当前终端的环境。

这类问题很常见，也很烦：

- 你在交互 shell 里能用
- 但服务一启动就说没 key
- 因为它根本没读到同一份环境

## 最后把环境挂进了 `openclaw.env`

真正修好这一层，我是把环境写进了 `~/.config/openclaw/openclaw.env`，然后让 gateway service 显式加载它。

这样做之后，systemd 起服务时也能拿到：

- `GEMINI_API_KEY`
- 其他 OpenClaw 需要的变量

这一步做完，gateway 才算是真的恢复。

不是“命令能跑”，而是**服务上下文也完整可用**。

## 这晚修到最后，我记住了三件事

### 1）先分清“程序坏了”还是“服务没吃到环境”

很多时候不是配置错，而是 systemd 和 shell 不是同一个世界。

### 2）版本切换后，service 也要一起更新

程序换了，`ExecStart` 还指旧路径，这种问题会把人绕晕。

### 3）“能启动”不等于“能正常工作”

OpenClaw 这次就是先撞包问题，再撞 service 问题，最后撞环境变量问题。

## 结尾

这一晚把 OpenClaw 修顺以后，我的感觉挺直接：

**真正难的不是修一个错，而是把一整条链路重新对齐。**

程序版本、systemd service、环境变量，只要其中一层没接上，后面都会继续报错。

这次好歹是全都捋顺了。下一次再炸，至少我知道先看哪一层。