---
title: "Noctalia v5 迁移与 dotfiles 管理"
urlSlug: 'noctalia-v5-dotfiles-stow-migration'
published: 2026-07-08
description: '记录一次从 Noctalia Quickshell 旧包迁移到 Noctalia v5 的过程，包括 AUR/包脚本检查、Niri 快捷键调整、GNU Stow 管理 dotfiles、XDG 用户目录英文化和最终验证。'
image: ''
author: ""
tags: ["Noctalia", "Niri", "GNU Stow", "dotfiles", "Arch Linux", "Linux 桌面", "实战记录"]
category: 'Linux 与开发环境'
draft: false
lang: 'zh_CN'
---

这次主要做了两件事：把桌面 Shell 从旧的 `noctalia-shell` 迁移到新的 `noctalia` v5，同时把相关配置整理进 dotfiles，用 GNU Stow 管起来。

相关仓库先放在这里，后面会提到它们各自的角色：

::github{repo="noctalia-dev/noctalia"}

::github{repo="YangYuS8/dotfiles"}

## 目标

这次调整的目标比较明确：

1. 从旧的 Quickshell 版 `noctalia-shell` 切到新的 `noctalia` 包；
2. 保留可回滚路径，先检查包来源和安装脚本，再动系统；
3. 把 Niri 里的启动项、快捷键和 layer rule 改到 v5 的命令；
4. 确认哪些配置应该进 dotfiles，哪些 runtime state 不应该进；
5. 顺手把主目录默认 XDG 用户目录从中文改成英文，保持路径风格统一。

最后的结果是：系统现在运行 `noctalia 5.0.0_beta1-3`，旧的 `noctalia-shell` 和 `noctalia-qs` 已经移除，Niri 配置、Noctalia 配置和 XDG 用户目录配置都已经纳入 dotfiles 管理。

## 环境

这次环境大致是：

- 系统：CachyOS / Arch-like Linux
- 桌面合成器：Niri
- dotfiles 管理：GNU Stow
- dotfiles 仓库：`/home/yangyus8/dotfiles`
- 原 Noctalia 旧包：`noctalia-shell 4.7.7-3`、`noctalia-qs 0.0.12-1.1`
- 新 Noctalia 包：`noctalia 5.0.0_beta1-3`

Niri 的 live 配置路径是：

```text
/home/yangyus8/.config/niri/config.kdl
```

但它实际是 stow 管理下的配置，指向 dotfiles 仓库里的源文件：

```text
/home/yangyus8/dotfiles/niri/.config/niri/config.kdl
```

这点很重要。否则很容易出现“我改了 `~/.config`，但 dotfiles 没同步”的情况。

## 迁移前先检查包

一开始我看到 AUR 上除了旧的 `noctalia-shell`，还有新的 `noctalia` 包，而且版本看起来更新。桌面 Shell 这种东西会常驻运行，还会接触通知、快捷键、状态栏、壁纸和插件，所以我没有直接安装，而是先做了几步检查。

主要看了这些内容：

- 当前系统里已安装的 `noctalia-shell`、`noctalia-qs`；
- 新旧包的文件列表和依赖关系；
- AUR 页面与 GitHub 仓库来源；
- `noctalia` 和 `noctalia-shell` 的 PKGBUILD；
- 是否有 `.install` 脚本；
- 构建过程里有没有明显可疑的 `curl | sh`、`wget | sh`、`base64 -d` 之类操作。

当时看到的新包源码指向 GitHub tag `v5.0.0-beta1`，构建方式是 Meson/Ninja，没有 `.install` 脚本，也没有发现明显可疑的安装逻辑。

对于 AUR 包，我现在更倾向于把这一步当成固定流程：

```bash
yay -Si noctalia
yay -G noctalia
cd noctalia
less PKGBUILD
```

如果是会常驻桌面的组件，更应该看一眼它会往系统里放什么、有没有安装后脚本，以及源码来源是不是对得上。

## 安装新包与清理旧包

确认包来源和脚本没有明显问题后，安装新包：

```bash
sudo pacman -Syu --needed noctalia
```

安装完成后，系统里有了新的主入口：

```text
/usr/bin/noctalia
```

之后再清理旧的 Quickshell 版：

```bash
sudo pacman -Rns noctalia-shell
```

这一步移除了旧包：

```text
noctalia-shell 4.7.7-3
noctalia-qs 0.0.12-1.1
```

当时也确认了旧命令已经不存在：

```text
qs -> not found
quickshell -> not found
```

新版本检查结果是：

```text
noctalia v5.0.0
```

CachyOS 的 pacman/snapper 也自动生成了快照。安装前后和移除旧包前后都有快照点，所以即使桌面 Shell 出问题，也不是完全没有退路。

## Niri 配置迁移

这次真正需要动手的地方，是 Niri 配置。

旧版 Noctalia 依赖 Quickshell，配置里很多命令长这样：

```kdl
spawn "qs" "-c" "noctalia-shell" "ipc" "call" ...
```

v5 之后有了独立的 `noctalia` 命令和新的 IPC 形式，所以我把快捷键改成了：

```kdl
spawn-sh "noctalia msg ..."
```

几个主要映射是：

| 快捷键 | 新命令 |
|---|---|
| `MOD+Space` | `noctalia msg panel-toggle launcher` |
| `MOD+S` | `noctalia msg panel-toggle control-center` |
| `MOD+Comma` | `noctalia msg settings-toggle` |

启动项也从旧版：

```kdl
spawn-at-startup "qs" "-c" "noctalia-shell"
```

改成：

```kdl
spawn-at-startup "noctalia"
```

另外 Noctalia v5 的 layer namespace 也和旧版不完全一样，所以我同步调整了相关 layer rule，例如 `noctalia-backdrop` 和 `noctalia-wallpaper`。

还有一个特殊点是录屏快捷键。旧版有 `screenRecorder toggle` 这样的 IPC 调用，但 v5 当前没有同名接口。我最后把 `MOD+R` 改成调用系统已有的 `gpu-screen-recorder` 脚本：

```text
/usr/share/gpu-screen-recorder/scripts/toggle-recording.sh
```

这比硬套旧 IPC 更稳。

## 把 Noctalia 配置纳入 stow

Niri 配置本来就在 dotfiles 里，但 Noctalia 自己的配置一开始不在。

当时检查到：

```text
/home/yangyus8/.config/noctalia
```

是一个真实目录，不是 symlink。dotfiles 仓库里也没有 `noctalia` 这个 stow 包。

后面我把 Noctalia 配置整理成了新的 stow 包：

```text
/home/yangyus8/dotfiles/noctalia/.config/noctalia/
```

现在 live 路径变成：

```text
/home/yangyus8/.config/noctalia -> ../dotfiles/noctalia/.config/noctalia
```

同时把 `noctalia` 加进了 `stow.sh` 的默认包列表。这样以后新机器或重新应用 dotfiles 时，Noctalia 配置也不会游离在仓库外。

这里有一个容易混淆的点：Noctalia v5 的有效用户配置可以通过下面的命令导出：

```bash
noctalia config export
```

我把导出的结果写进：

```text
noctalia/.config/noctalia/config.toml
```

然后把原来的：

```text
~/.local/state/noctalia/settings.toml
```

移走了。

原因是，如果 `settings.toml` 继续留在 state 目录里，它可能覆盖 dotfiles 里的配置。表面上看配置被 stow 管了，实际运行时却被 state 覆盖，这种状态以后很难排查。

不过，不是所有 Noctalia 相关文件都适合进 dotfiles。

我认为适合管理的是：

- `~/.config/noctalia/config.toml`
- `~/.config/noctalia/colors.json`
- `~/.config/noctalia/plugins.json`
- 本地安装并且想保留的插件目录

不适合直接管理的是：

- `~/.local/state/noctalia/notification_history.json`
- `~/.local/state/noctalia/clipboard/`
- `~/.local/state/noctalia/plugin-cache/`
- `~/.local/state/noctalia/community-templates/`
- `~/.local/state/noctalia/community-palettes/`

这些更像运行时缓存、历史记录或下载内容，不应该和长期配置混在一起。

## 顺手整理 XDG 用户目录

这次还顺手把主目录里的中文默认目录改成了英文。

原来是：

```text
桌面 下载 模板 公共 文档 音乐 图片 视频
```

现在改成：

```text
Desktop Downloads Templates Public Documents Music Pictures Videos
```

对应的 XDG 配置是：

```text
~/.config/user-dirs.dirs
~/.config/user-dirs.locale
```

这两个文件现在也纳入了 dotfiles 的 `desktop` stow 包：

```text
desktop/.config/user-dirs.dirs
desktop/.config/user-dirs.locale
```

迁移时没有直接粗暴覆盖目录，而是先检查了中英文目录是否同时存在、是否有内容、是否有同名冲突。比如 `Videos` 原本就存在，所以 `视频` 里的内容是合并进去的。

GTK 文件选择器书签也同步改成了英文路径和英文显示名：

```text
desktop/.config/gtk-3.0/bookmarks
desktop/.config/gtk-4.0/bookmarks
```

最后确认 `xdg-user-dir` 输出已经全部指向英文目录。

## 验证

配置改完后，我做了几类验证。

Niri 配置验证：

```bash
niri validate -c /home/yangyus8/.config/niri/config.kdl
```

结果里有：

```text
config is valid
```

Noctalia 配置验证：

```bash
noctalia config validate
```

结果是：

```text
✓ Config is valid
```

后来加入更多桌面 widget 后，这个命令曾出现过一个 warning：

```text
widget.notes: unrecognized widget type "noctalia/notes:notes"
```

但整体配置仍然是 valid。这个 warning 后面可以再单独看是插件缺失、类型名变化，还是某个 widget 残留配置。

Noctalia IPC 状态检查：

```bash
noctalia msg status
```

当时返回的关键状态是：

```json
{
  "barVisible": true,
  "panelOpen": false,
  "locked": false
}
```

Stow 检查也跑过：

```bash
cd ~/dotfiles
./stow.sh
./stow.sh noctalia
```

dry-run 没有冲突。

最后 dotfiles 提交到了：

```text
197bfa0 feat(desktop): manage noctalia and themed desktop config
```

这次提交里包含：

- Noctalia stow 包；
- Niri 的 Noctalia v5 启动和快捷键调整；
- XDG 用户目录英文化配置；
- GTK bookmarks；
- Noctalia 生成的 Alacritty、btop、GTK、Neovim 等主题相关配置。

## 这次整理后的经验

这次最大的收获不是“装了一个新版本”，而是把桌面环境的配置边界理清了。

我现在更倾向于这样分层：

1. **包管理器负责安装程序。** 比如 `pacman` 安装 `noctalia`。
2. **dotfiles 负责长期配置。** 比如 Niri、Noctalia、GTK bookmarks、XDG user dirs。
3. **state 目录只放运行时状态。** 比如通知历史、剪贴板、缓存、下载的模板目录。
4. **每次迁移都要有验证。** 配置文件能不能通过、进程是否正常、快捷键是否对应新命令，都要实际检查。

这也提醒我，dotfiles 不只是“把配置文件放到 Git 里”。真正有用的 dotfiles，应该能回答几个问题：

- 这份配置是不是当前系统真正使用的配置？
- 这个文件适不适合长期同步到别的机器？
- 如果程序升级导致命令变化，相关启动项和快捷键有没有一起迁移？
- 如果出问题，能不能知道从哪里回滚？

这次 Noctalia v5 迁移刚好把这些问题都走了一遍。后面再整理别的桌面组件时，也可以按这个流程来：先检查包，再迁移配置，再区分 config 和 state，最后用 stow 和实际命令验证。
