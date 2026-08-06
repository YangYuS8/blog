---
title: "CachyOS 启动卡死：定位并止损 systemd 重启风暴"
urlSlug: 'cachyos-boot-freeze-systemd-restart-storm'
published: 2026-08-06
description: '一次系统更新后的启动卡死排查：通过 journalctl、coredumpctl 和 systemd 状态定位到 aTrust 崩溃循环与遗留 Clash Verge 服务，并以最小可逆操作止损。'
image: ''
author: ""
tags: ["CachyOS", "Arch Linux", "systemd", "aTrust", "故障排查", "实战记录"]
category: 'Linux 与开发环境'
draft: false
lang: 'zh_CN'
---

一次常规系统更新并重启后，桌面在登录不久会突然卡死。最初很容易把怀疑对象放在刚升级的内核、AMD 核显或文件系统上；但日志给出的结论更具体：两个 systemd 服务都在失败重启，其中深信服 aTrust 的崩溃循环会遗留子进程并持续堆积资源。

这篇记录排查路径和止损方式。文中的服务名、版本和日志均来自这次本机事故；其中 aTrust 是公司 VPN / 零信任客户端，处理前应先确认暂停它不会影响当前工作。

## 现象

更新完成后安装了新内核：

```text
linux-cachyos 7.1.5-1 -> 7.1.6-1
linux-cachyos-lts 6.18.40-1 -> 6.18.42-1
```

重启后连续出现短生命周期的启动记录：系统能进入图形界面，但大约一两分钟后失去响应，只能强制重启。`last -x` 中出现多次 `crash`，每次运行时间只有两三分钟。

这类问题不要先回滚整个系统快照。先保留证据，区分以下几类原因：

- 内核锁死、GPU reset、NVMe 或 Btrfs 错误；
- 内存耗尽和 OOM killer；
- 某个用户态服务崩溃并不断重启；
- 已卸载软件遗留的 systemd 单元持续失败。

## 环境

- 系统：CachyOS / Arch Linux
- 内核：`linux-cachyos 7.1.6-1`
- GPU：AMD Radeon 680M，驱动 `amdgpu`
- 桌面会话：Niri Wayland
- 文件系统：Btrfs，系统盘为 NVMe
- 常驻客户端：`atrust-bin 2.5.16.30-4`

## 先确认是不是内核或硬件问题

先看当前和上一轮启动中的高优先级日志：

```bash
journalctl -b -p warning..alert --no-pager
journalctl -b -1 -p warning..alert --no-pager
journalctl -k -b --no-pager | grep -Ei \
  'oom|hung|stall|lockup|gpu|amdgpu|nvme|btrfs|mce|hardware'
```

再检查失败单元、内存和启动历史：

```bash
systemctl --failed --no-pager
free -h
last -x | head -n 30
```

这次没有看到 OOM killer、amdgpu reset、NVMe timeout、Btrfs error、MCE 或 kernel lockup。内存也还有约 11 GiB 可用。

启动期间会出现少量 ACPI BIOS warning、VirtualBox 的 out-of-tree module taint 以及 `clocksource` 超时提示，但它们没有和卡死时刻形成因果链。排查时不要把“看起来可怕的 warning”当成根因，真正的失败通常会反复出现并带有明确的服务名、退出码或 coredump。

## 排查 systemd 服务

接着筛选本次启动中的异常事件：

```bash
journalctl -b --no-pager -o short-iso | grep -Ei \
  'segfault|core-dump|restart|failed|oom|lockup|amdgpu|nvme|btrfs'

systemctl list-units --type=service --all --no-pager | \
  grep -E 'aTrust|clash|plasma|sddm|niri'
```

很快能看到两个稳定复现的问题。

### aTrustAgent 每约 35 秒崩溃一次

内核日志重复出现：

```text
aTrustAgent[...] segfault at 28 ... in libcrypto.so.1.1
systemd-coredump: Process ... (aTrustAgent) dumped core.
aTrustDaemon.service: Main process exited, code=dumped, status=11/SEGV
```

`coredumpctl list` 可以确认它不是偶发事件：同一个 `aTrustAgent` 在每次启动中多次以 `SIGSEGV` 退出。

```bash
coredumpctl list --no-pager | tail -n 30
systemctl cat aTrustDaemon.service
systemctl show aTrustDaemon.service \
  -p ActiveState -p SubState -p Restart -p RestartUSec -p NRestarts \
  --no-pager
```

服务定义包含：

```ini
Restart=always
RestartSec=5s
KillMode=process
```

这三个配置组合解释了为何桌面会越来越卡：主进程崩溃后，systemd 五秒后重新拉起它；而 `KillMode=process` 没有把整个 cgroup 的子进程一并结束。日志也明确报告了遗留的 `aTrustXtunnel-64` 与 `aTrustAgent`：

```text
aTrustDaemon.service: Unit process ... remains running after unit stopped.
aTrustDaemon.service: Found left-over process ... while starting unit.
```

观察到的 cgroup 内存会随着重启上升。它并不是一次性撑爆内存才触发 OOM，而是反复崩溃、重启和残留进程造成的资源与调度风暴。

进一步用 `ldd` 和 `readelf` 检查后发现，aTrust 会加载自己打包的 OpenSSL 1.1：

```bash
readelf -d /usr/share/sangfor/aTrust/resources/bin/aTrustAgent | grep NEEDED
ldd /usr/share/sangfor/aTrust/resources/bin/aTrustAgent | grep -E 'ssl|crypto|curl'
```

因此，不能仅凭“今天升级了内核”就断言是 `linux-cachyos` 的回归。这里能够确认的是：崩溃发生在 aTrust 用户态网络组件及其捆绑的 `libcrypto.so.1.1` 调用链中；是否与系统运行时组合有关，仍需由客户端供应商或后续独立复现确认。

### 已卸载的 Clash Verge 服务每 5 秒失败一次

另一个单元也处于无限重启状态：

```text
clash-verge-service.service: Failed at step EXEC spawning /usr/bin/clash-verge-service: No such file or directory
clash-verge-service.service: Main process exited, code=exited, status=203/EXEC
```

它的单元文件仍在，但目标二进制已经不存在：

```ini
ExecStart=/usr/bin/clash-verge-service
Restart=always
RestartSec=5
```

这是卸载旧版 Clash Verge 后没有同步禁用 systemd 单元留下的尸体。它不是本次卡死的唯一证据，但会每五秒产生一次无意义的失败和重启，应该一并清理。

## 根因

本次事故的直接根因是两个服务共同构成的重启风暴，其中严重程度不同：

1. **aTrustDaemon 是主因。** `aTrustAgent` 持续在其 OpenSSL 网络调用链中触发 `SIGSEGV`；服务策略强制重启，停止时又残留 aTrust 子进程。
2. **clash-verge-service 是并存的配置债务。** 它已经找不到可执行文件，却仍被设置为无限重启。
3. **新内核不是已证实的根因。** 本次没有内核、GPU、存储或 OOM 级别错误可将卡死归因给 `7.1.6-1`。

排查结论应严格区分“与本次更新同时发生”和“由更新导致”。后者没有证据时，不应该为了求快就整体回滚。

## 止损

如果当前不需要 aTrust VPN，可以先做可逆止损：停止并禁用两个单元，再清理 aTrust 残留 cgroup。

```bash
sudo systemctl disable --now clash-verge-service.service
sudo systemctl disable --now aTrustDaemon.service
sudo systemctl kill --kill-whom=all --signal=SIGKILL aTrustDaemon.service
sudo systemctl reset-failed aTrustDaemon.service
```

这里要注意两点：

- `disable --now` 同时处理当前运行实例和下次开机自启；
- aTrust 的停止脚本没有可靠结束全部子进程，所以额外使用 `systemctl kill --kill-whom=all` 清理整个服务 cgroup。

对于已卸载软件遗留的单元，后续可在确认不再使用后删除其 unit 文件；这次先禁用即可，避免扩大变更范围。

## 验证

止损后不应只看 `systemctl stop` 返回成功，而要观察一段时间：

```bash
for unit in aTrustDaemon.service clash-verge-service.service; do
  echo "-- $unit --"
  systemctl is-enabled "$unit" || true
  systemctl is-active "$unit" || true
  systemctl show "$unit" -p ActiveState -p SubState -p NRestarts --no-pager
 done

pgrep -a -f 'aTrustAgent|aTrustXtunnel|clash-verge-service' || true
systemctl --failed --no-pager
```

本次操作后，两个服务均为：

```text
disabled
inactive
ActiveState=inactive
SubState=dead
NRestarts=0
```

随后观察 75 秒，重启计数没有增长，未再发现 aTrust、aTrustXtunnel 或 Clash Verge 服务进程，`systemctl --failed` 也回到 0 个失败单元。观察窗口内没有新的 OOM、GPU、NVMe、Btrfs、lockup 或 segfault 记录。

这说明止损生效；它不等于 aTrust 已经修复，只是把已确认的故障源从启动路径中移除。

## 后续处理建议

需要再次使用 aTrust 前，不要直接重新启用开机自启。更合理的顺序是：

1. 询问公司 IT 或供应商是否有适配当前 Arch/CachyOS、OpenSSL 与 Wayland 环境的新客户端；
2. 在独立测试窗口中手动启动 aTrust，收集新的 `journalctl -u aTrustDaemon.service` 与 `coredumpctl` 证据；
3. 若必须长期使用，优先寻找官方支持的容器、虚拟机或受支持发行版运行方式，而不是长期容忍一个 root 常驻崩溃服务；
4. 在确定稳定前保持服务禁用，只在确实需要 VPN 时临时启用并观察。

## 总结

系统更新后出现卡死，并不代表新内核一定有问题。先用日志把问题缩小到具体服务，再检查其重启策略、子进程清理和资源变化，往往比盲目回滚更快、更安全。

这次真正需要移除的是 aTrust 的崩溃循环和遗留 Clash Verge 单元。停止、禁用并验证没有残留后，系统恢复稳定；而 aTrust 的兼容性修复则应作为独立问题继续处理。
