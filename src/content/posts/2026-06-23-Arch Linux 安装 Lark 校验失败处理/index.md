---
title: "Arch Linux 安装 Lark 校验失败处理"
urlSlug: 'arch-linux-lark-aur-checksum-fix'
published: 2026-06-23
description: '记录 Arch/CachyOS 上通过 AUR 安装国际版飞书 Lark 时遇到 larksuite-bin b2sums 校验失败的排查过程，以及中途遇到的 CachyOS 仓库签名问题。'
image: ''
author: ""
tags: ["Arch Linux", "AUR", "Lark", "CachyOS", "故障排查", "新手教程"]
category: 'Linux 与开发环境'
draft: false
lang: 'zh_CN'
---

## 目标

这篇记录一次在 Arch Linux / CachyOS 上安装国际版飞书 Lark 的排查过程。

我当时使用 AUR 包 `larksuite-bin` 安装 Lark，结果卡在完整性校验：`.deb` 文件下载完成了，但 `b2sums` 校验失败。中途还遇到了 CachyOS 仓库签名错误，所以这篇把两个容易混在一起的问题分开记录一下。

最终结论很简单：

- `larksuite-bin` 安装失败的核心原因，是 AUR `PKGBUILD` 中记录的 `b2sums` 与实际下载到的 `Lark-linux_x64-7.66.10.deb` 不一致；
- 这通常不是 `yay` 坏了，也不是本机缺编译依赖；
- 不建议直接 `--skipinteg` 跳过校验；
- 更稳妥的做法是清理缓存后重试，仍失败时检查下载文件和 `PKGBUILD`，再用 `updpkgsums` 本地更新校验值后手动构建。

## 环境

本次问题发生在 Arch 系发行版环境中：

- 系统：CachyOS / Arch Linux 系；
- AUR helper：`yay`；
- 目标软件：国际版飞书 Lark；
- AUR 包：`larksuite-bin`；
- 出问题版本：`7.66.10-1`。

如果你使用的是 Arch、EndeavourOS、CachyOS 或其它 Arch 系发行版，排查思路基本一致。

## 现象

安装命令类似：

```bash
yay -S larksuite-bin
```

构建过程中可以看到 `.deb` 文件正常下载，但完整性校验失败：

```text
==> 正在验证 source 文件，使用b2sums...
Lark-linux_x64-7.66.10.deb ... 失败
LICENSE-20260122.html ... 通过
LICENSE-US-20260122.html ... 通过
dlagent-lark.sh ... 通过
dlagent-license.sh ... 通过
dlagent-license-global.sh ... 通过
dlagent-license-US.sh ... 通过
==> 错误： 一个或多个文件没有通过有效性检查！
```

同时日志里能看到下载的是同一个版本：

```text
AUR Explicit (1): larksuite-bin-7.66.10-1
正在下载 Lark-linux_x64-7.66.10.deb...
100 417.6M
```

也就是说，包版本看起来没有错，下载也不是完全失败，真正失败的是 `PKGBUILD` 里记录的校验值和当前文件内容对不上。

## 根因判断

AUR 包的 `PKGBUILD` 会写明源码文件地址和校验值，例如 `sha256sums`、`b2sums` 等。构建时，`makepkg` 会先下载文件，再计算本地文件的校验值，与 `PKGBUILD` 中的值比较。

这次报错说明：

> AUR 里的 `b2sums` 记录值，和实际下载到的 `Lark-linux_x64-7.66.10.deb` 内容不一致。

常见原因有三种：

1. Lark 官方替换了同版本 `.deb` 文件，但 AUR 维护者还没更新校验值；
2. 本地缓存里的 `.deb` 下载损坏；
3. 下载源被污染或文件被篡改。

第三种概率不一定高，但不能完全忽略。尤其 `larksuite-bin` 这种闭源大体积二进制包，不应该看到校验失败就直接跳过。

## 第一步：清理 yay 缓存后重试

先排除本地缓存损坏。

```bash
rm -rf ~/.cache/yay/larksuite-bin
yay -S larksuite-bin
```

如果清理缓存后安装成功，说明之前大概率是缓存中的下载文件有问题。

如果清理缓存后仍然是同样的 `b2sums` 校验失败，那么基本可以判断为：

> AUR 包里的校验值滞后，或者上游同版本文件内容发生了变化。

这时不要急着 `--skipinteg`，先检查文件和构建脚本。

## 第二步：检查下载到的 `.deb` 文件

进入 AUR 构建目录：

```bash
cd ~/.cache/yay/larksuite-bin
```

检查 `.deb` 是否至少是正常 Debian 包格式：

```bash
file Lark-linux_x64-7.66.10.deb
bsdtar -tf Lark-linux_x64-7.66.10.deb | head
```

正常情况下，`bsdtar` 应该能列出类似内容：

```text
debian-binary
control.tar.*
data.tar.*
```

这一步只能做基础格式检查，不能证明文件绝对可信。但它能排除“下载下来的根本不是 deb 包”这种明显异常。

## 第三步：本地更新 PKGBUILD 校验值

如果确认下载文件格式正常，并且你愿意接受当前上游文件，可以在本地更新校验值后手动构建。

如果系统没有 `updpkgsums`，先安装：

```bash
sudo pacman -S pacman-contrib
```

然后在 AUR 构建目录中执行：

```bash
cd ~/.cache/yay/larksuite-bin
updpkgsums
```

`updpkgsums` 会重新计算 `PKGBUILD` 中 source 文件的校验值，并原地更新 `PKGBUILD`。

更新后一定要看差异：

```bash
git diff PKGBUILD
```

正常情况下，应只看到 `b2sums=(...)` 里对应 `.deb` 的校验值变化。

如果 `source=...`、`prepare()`、`package()` 等逻辑也出现了陌生改动，就应该停下来，不要继续安装。

确认无异常后再构建安装：

```bash
makepkg -si
```

完整命令可以整理成：

```bash
cd ~/.cache/yay/larksuite-bin
updpkgsums
git diff PKGBUILD
makepkg -si
```

## 不推荐：直接跳过完整性检查

不建议这样做：

```bash
makepkg -si --skipinteg
```

`--skipinteg` 会直接跳过完整性校验。对普通文本源码包已经不太优雅，对闭源二进制包更不应该随手这么做。

更稳妥的路线是：

1. 清理缓存重新下载；
2. 检查 `.deb` 基本格式；
3. 查看 `PKGBUILD` 是否只有校验值变化；
4. 使用 `updpkgsums` 更新本地校验值；
5. 再 `makepkg -si` 构建安装。

## 插曲：CachyOS 仓库签名错误

排查过程中，我还遇到了另一个问题。当时执行过：

```bash
yay -Syu larksuite-bin
```

结果被系统仓库同步挡住：

```text
错误：cachyos-extra-v3: 来自 "CachyOS <admin@cachyos.org>" 的签名无效
错误：未能同步所有数据库（未预期的错误）
-> 刷新数据库时出错 - exit status 1
```

这个问题和 `larksuite-bin` 本身不是一回事。

`yay -Syu larksuite-bin` 会先同步并更新系统，再处理目标包。如果系统仓库签名或 keyring 有问题，安装 Lark 前就会被挡住。

可以按下面顺序处理。

### 检查系统时间

```bash
timedatectl
```

如果时间不对：

```bash
sudo timedatectl set-ntp true
```

### 重新测速 CachyOS 镜像

```bash
sudo cachyos-rate-mirrors
sudo pacman -Syyu
```

### 更新 keyring

```bash
sudo pacman -Sy archlinux-keyring cachyos-keyring
sudo pacman -Syyu
```

### 最后手段：重置 pacman keyring

如果仍然失败，再考虑重置 keyring：

```bash
sudo rm -rf /etc/pacman.d/gnupg/
sudo pacman-key --init
sudo pacman -Sy archlinux-keyring cachyos-keyring
sudo pacman-key --populate archlinux cachyos
sudo pacman -Syyu
```

注意，这一步影响系统包管理签名信任链，不要一上来就做。只有前面的方法都不行时再考虑。

在我的这次排查里，系统仓库更新恢复正常后，`larksuite-bin` 仍然报 `.deb` 校验失败，因此最终问题还是回到了 AUR 包自身的 `b2sums` 不匹配。

## `yay -Syu larksuite-bin` 和 `yay -S larksuite-bin` 的区别

这次也顺手理清了一个容易混淆的点。

```bash
yay -Syu larksuite-bin
```

这会执行系统同步和升级，因此可能先暴露系统仓库、镜像、keyring 问题。

如果只是想安装 Lark，可以先用：

```bash
yay -S larksuite-bin
```

但即使系统仓库正常，`larksuite-bin` 自己仍可能因为 `.deb` 校验失败而无法构建。

## 总结

这次问题可以分成两层：

1. CachyOS 仓库签名失败：先处理系统时间、镜像和 keyring；
2. `larksuite-bin` 校验失败：核心是 AUR `PKGBUILD` 中的 `b2sums` 和实际 `.deb` 内容不一致。

最终推荐路线：

```bash
rm -rf ~/.cache/yay/larksuite-bin
yay -S larksuite-bin
```

如果仍然失败：

```bash
cd ~/.cache/yay/larksuite-bin
sudo pacman -S pacman-contrib
updpkgsums
git diff PKGBUILD
makepkg -si
```

关键检查点是：

```bash
git diff PKGBUILD
```

只接受校验值变化，不要无脑跳过完整性检查。

AUR 包出问题时，最容易犯的错是把所有报错都归到一个原因上。实际上这次至少有两件事：系统仓库签名和 AUR source 校验。先把它们拆开，再逐个验证，排查会清楚很多。
