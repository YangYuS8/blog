---
title: "OpenClaw 为什么吃不到我的系统环境：从 fnm 到可复用环境文件"
urlSlug: '20260408-02'
published: 2026-04-08
description: '记录一次很典型的环境继承排障：OpenClaw 执行命令时吃不到我在 shell 里通过 fnm 和 .bashrc 配好的 node、pnpm、代理环境，最后改成显式可 source 的环境文件解决。'
image: ''
tags: ['OpenClaw', 'fnm', 'Node.js', 'pnpm', 'shell', '环境变量']
category: '问题排查'
draft: false 
lang: 'zh_CN'
---

这次问题本身不复杂，但很容易把人绕晕。

我以为我的系统环境已经配好了，结果 OpenClaw 还是吃不到：

- `node` 找不到
- `pnpm` 找不到
- `playwright-cli` 起不来
- 代理变量也没按我想的方式进到非交互 shell

最开始我还以为是工具坏了，后来才发现，问题根本不在工具，而在**我以为它会继承我的 shell 环境**。

## 一开始为什么会误判

我本机平时是靠 `fnm` 管 Node 版本的，`.bashrc` 里也写了初始化逻辑。

看起来一切都挺正常：

- 交互式终端里 `node` 是有的
- `pnpm` 也在 PATH 里
- `~/.profile` 会再去 source `~/.bashrc`

但 OpenClaw 跑命令时，实际用的是另一层执行上下文，不是我打开终端的那个 shell。

这就导致一个很烦的现象：

> 我在自己终端里明明能用，OpenClaw 里却说没有。

## 先查 `.bashrc` 和 `.profile`

我当时先确认了一遍启动脚本：

- `~/.bashrc` 里确实有 `fnm env --shell bash`
- `~/.profile` 也会 source `~/.bashrc`
- 但这只保证**登录 shell / 交互 shell** 的行为

问题是，OpenClaw 触发的那些命令，并不一定会走到这条路径。

换句话说：

- 你的日常终端是一套环境
- 自动化执行器是另一套环境

它们不是天然相通的。

## 为什么我最后没继续赌 shell 自动继承

最开始我尝试过直接让命令先 `source ~/.profile`。

这思路没错，但不够稳，因为它还是依赖 shell 类型和启动顺序。

后来我干脆改成一件更确定的事：

**把需要的环境变量整理成一个明确可 source 的文件。**

这样不管是我自己跑，还是 OpenClaw 跑，都可以先显式加载同一份环境。

## 我最后整理出的关键环境

我把这些东西都放进了一个单独的环境文件里：

- `FNM_DIR`
- `PNPM_HOME`
- `PATH`
- `http_proxy` / `https_proxy` / `no_proxy`
- `HTTP_PROXY` / `HTTPS_PROXY` / `NO_PROXY`
- `openclaw.env`

这样做的好处很直接：

- 不依赖交互 shell
- 不依赖 login shell
- 不依赖当前是不是在 tmux / zellij / 终端窗口里
- 任何命令都能先手动 source 再执行

## 我现在是怎么用的

我现在会先让命令显式加载这份环境，再跑需要的工具。

比如：

```bash
source /home/geneden/.openclaw/workspace/.openclaw-env.sh
```

或者用一个更完整的入口：

```bash
source /home/geneden/.openclaw/workspace/.openclaw-env.bash
```

这样 `fnm`、`pnpm`、代理变量都会到位。

## 这次问题真正的关键点

这次最值得记住的一点其实很简单：

**自动化工具不会因为你“平时终端里有”就自动继承那些环境。**

尤其是这些东西：

- `fnm`
- `pnpm`
- 代理变量
- 需要给 systemd / 非交互 shell 用的配置

最好都显式写进一个可复用的环境入口里。

## 结尾

这次折腾完，我反而觉得更清楚了。

不是 OpenClaw 不能用我的环境，而是我一开始把“我的终端环境”误认为了“所有执行环境”。

修正方法也不复杂：

- 交互 shell 继续按习惯配
- 自动化执行单独准备一份可 source 的环境文件

这样以后再遇到 `node not found`、`pnpm not found`、`playwright 起不来` 这种问题，先加载环境，再谈别的，省很多时间。
