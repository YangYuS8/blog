---
title: "niri 与 Noctalia 的 OOM 故障隔离"
urlSlug: 'noctalia-oom-cgroup-isolation'
published: 2026-10-11
description: '从 systemd-oomd 日志找到桌面退出的原因，将 Noctalia 交给用户服务管理，并让启动的应用进入独立 cgroup。'
image: ''
author: "杨与S8"
tags: ['Linux', 'CachyOS', 'niri', 'Noctalia', 'systemd', 'OOM']
category: 'Linux 与开发环境'
draft: false
lang: 'zh_CN'
---

10 月 11 日，CachyOS 上的桌面出了故障。这台机器用的是 niri、Wayland 和 Noctalia。检查进程与会话状态后，发现 niri 还在运行，退出的是 Noctalia。

窗口合成器与桌面壳分开运行，我继续查用户日志、layer-shell 和进程归组。下面几条是这类现场可用的只读检查：

```bash
pgrep -a 'niri|noctalia'
journalctl -b -u systemd-oomd --no-pager
niri msg layers
```

当时的日志显示，系统内存与 swap 使用均超过 90%，Noctalia 所在的 scope 随后被 systemd-oomd 终止。另有记录显示，该 scope 的内存峰值约 5 GiB。这里要分清统计范围：90% 对应系统级用量；5 GiB 是 scope 内进程的合计峰值，不能直接归成“Noctalia 自己用了 5 GiB”，更不能据此认定它有内存泄漏。[systemd-oomd 用量阈值说明](https://www.freedesktop.org/software/systemd/man/latest/oomd.conf.html#SwapUsedLimit=)

systemd-oomd 会选中 cgroup，并向其中所有进程发送 SIGKILL。它的官方手册也专门提醒：把太多进程放在同一个会话 scope 下，可能让一个高内存任务触发整组终止。因此，排查要继续看进程属于哪个 cgroup。[systemd-oomd 手册](https://www.freedesktop.org/software/systemd/man/latest/systemd-oomd.service.html)

原来的 niri 配置通过 `spawn-at-startup "noctalia"` 启动桌面壳。这是 niri 支持的启动方式；本次修复需要进一步把桌面壳和它启动的应用交给 systemd 分别管理。[niri 启动项文档](https://github.com/niri-wm/niri/wiki/Configuration:-Miscellaneous#spawn-at-startup)

实际改动分成两部分。先把 Noctalia 迁到独立的 systemd 用户服务，放进 `session.slice`，设置 `Restart=on-failure` 和 3 秒重启间隔，再移除 niri 中原有的重复启动项。这样桌面壳有了独立的服务状态、日志和失败后重启策略。`on-failure` 会在符合条件的异常退出后尝试重启，仍受服务启动频率限制。[systemd 服务重启规则](https://www.freedesktop.org/software/systemd/man/latest/systemd.service.html#Restart=)

接着启用 Noctalia 的 `launch_apps_as_systemd_services`。官方说明，这会让从启动器、Dock 和任务栏打开的应用成为临时用户服务，获得各自的 cgroup；前提是 Noctalia 自身已经运行在 systemd 用户管理器下。仅在普通会话子进程里打开这个开关，选项会被忽略。[Noctalia Shell 配置](https://docs.noctalia.dev/noctalia/configuration/shell/)

这些应用服务使用 `OOMPolicy=continue`，用于控制进程被 OOM killer 终止后 systemd 如何处理同一服务的其他进程。应用仍然受 OOM 策略约束，独立 cgroup 的作用是缩小故障牵连范围。

修改中还遇到一次配置校验失败：把 niri 配置复制到备份目录后，里面的相对引用 `include "./noctalia.kdl"` 找不到原文件了。保留 include 的目录关系后，校验通过。启动时出现的可选工具、模板和 widget 警告也逐项区分，没有把它们当成这次退出的原因。

恢复验收没有停在“进程又出现了”。Noctalia 服务处于 `active/running`，配置与服务文件校验通过，bar、Dock、wallpaper 层存在，启动器可以打开。新启动的应用出现在独立的 `app-*` cgroup 中。崩溃后接管通知的 mako 被停止，D-Bus 通知服务也重新由 Noctalia 持有。

当时 `NRestarts=0`，即自动重启计数为 0，并不代表 OOM 后的自动恢复已经实测通过。本次完成的是桌面恢复与进程归组验收，没有主动复现内存压力，也没有长期稳定性数据；造成内存压力的具体进程仍待单独排查。
