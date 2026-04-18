---
title: "Git SSH 密钥怎么配：从生成密钥到让 GitHub 走 SSH 的一份完整上手教程"
urlSlug: '20260418-01'
published: 2026-04-18
description: '一篇偏上手向的 Git SSH 配置教程：从检查本机现有密钥、生成新的 SSH key、添加到 ssh-agent、上传公钥到 GitHub，再到测试 SSH 是否生效，以及把仓库远程地址切换成 SSH。'
image: ''
tags: ['Git', 'GitHub', 'SSH', 'Linux', '教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

如果你平时用 GitHub 主要还是 HTTPS 拉代码，那你大概率遇到过这些情况：

- push 的时候总要认证
- 换了环境以后又要重新登录
- 想在服务器或开发机上长期稳定地用 Git，却不想反复输账号密码或 token

这种时候，最省心的做法通常就是：

**把 GitHub 的仓库访问方式切到 SSH。**

这样配置好以后，后面常见的 `git clone`、`git pull`、`git push` 都会顺很多。

这篇文章我就按 GitHub 官方文档推荐的思路，整理一遍比较完整的 SSH 配置流程，包括：

- 先检查本机有没有现成 SSH key
- 没有的话怎么生成新的 key
- 怎么把 key 加进 `ssh-agent`
- 怎么把公钥添加到 GitHub
- 怎么测试 SSH 是否真的可用
- 怎么把仓库远程地址切到 SSH

## 先说一句：这里配置的是“GitHub 用的 SSH key”

这篇讲的是：

> **让 Git / GitHub 通过 SSH 认证来访问仓库。**

所以它和“你用 SSH 远程登录服务器”那类场景相关，但不是同一件事。

- 远程登录服务器，通常是：`ssh user@host`
- GitHub SSH 配置，主要是为了：`git@github.com`

也就是说，这里重点是**Git 仓库认证**，不是服务器登录本身。

## 第一步：先检查本机有没有现成的 SSH key

GitHub 官方也建议先看一下本机有没有已经能用的 key，不要一上来就重复生成。

直接看 `~/.ssh` 目录：

```bash
ls -al ~/.ssh
```

常见会看到这些文件名：

- `id_ed25519`
- `id_ed25519.pub`
- `id_rsa`
- `id_rsa.pub`

其中：

- 没有后缀的，是**私钥**
- `.pub` 结尾的，是**公钥**

如果你已经有一对 SSH key，而且就是你准备继续用的那一对，那就不一定需要重新生成。

## 第二步：生成新的 SSH key

如果你没有现成可用的 key，或者想专门为 GitHub 单独生成一套，那就可以新建一对。

GitHub 官方现在更推荐使用：

- `ed25519`

### 推荐命令

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

这里的邮箱一般可以写你 GitHub 账号对应的邮箱，主要作用更像注释，方便你后面识别这把 key 是干什么的。

执行以后，终端通常会问你两件事：

### 1）密钥文件保存到哪里

如果你直接回车，一般会默认保存到：

```text
~/.ssh/id_ed25519
```

如果你不想覆盖已有 key，也可以自己取个名字，例如：

```text
~/.ssh/id_ed25519_github
```

### 2）要不要设置 passphrase

这里建议按自己的使用场景决定：

- **更安全**：设置 passphrase
- **更省事**：不设 passphrase

如果是自己的长期开发机，很多人会设置 passphrase，然后交给 `ssh-agent` 记住。

## 如果你的环境不支持 ed25519 怎么办

GitHub 官方也给了兼容方案。

如果你的系统太旧，`ed25519` 不可用，也可以退回到 RSA：

```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

不过如果环境支持，还是更建议优先用 `ed25519`。

## 第三步：启动 ssh-agent

生成 key 之后，下一步通常是把私钥交给 `ssh-agent` 管理。

这样你后面用 Git 的时候，就不用每次都重新处理密钥。

先启动 agent：

```bash
eval "$(ssh-agent -s)"
```

如果正常，会看到类似：

```text
Agent pid 12345
```

## 第四步：把私钥加到 ssh-agent

如果你用的是默认文件名：

```bash
ssh-add ~/.ssh/id_ed25519
```

如果你刚才是自己起名的，例如：

```bash
ssh-add ~/.ssh/id_ed25519_github
```

这里加的是**私钥文件**，不是 `.pub` 公钥文件。

## 第五步：按需要配置 `~/.ssh/config`

如果你只有一把默认 key，有时甚至不配也能正常工作。

但如果你：

- 有多把 key
- 想明确指定 GitHub 走哪一把 key
- 想让 agent 行为更稳定

那最好还是写一下 `~/.ssh/config`。

先确保文件存在：

```bash
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

然后写入类似内容：

```text
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
```

如果你使用的是自定义文件名，就把 `IdentityFile` 改成你自己的路径。

### macOS 用户常见写法

如果你在 macOS 上，还经常会看到这种：

```text
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
  UseKeychain yes
```

这里的 `UseKeychain yes` 是 macOS 相关配置，不是所有系统都需要。

## 第六步：复制公钥内容

下一步就是把**公钥**添加到 GitHub 账号。

如果你用的是默认 key：

```bash
cat ~/.ssh/id_ed25519.pub
```

如果你用的是自定义文件名，就改成对应的 `.pub` 文件。

你会看到一整行类似这样的内容：

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...... your_email@example.com
```

这一整行都要复制，不要只复制中间一段。

### 各平台更方便的复制方式

#### macOS

```bash
pbcopy < ~/.ssh/id_ed25519.pub
```

#### Linux（如果装了 xclip）

```bash
xclip -sel clip < ~/.ssh/id_ed25519.pub
```

#### Windows Git Bash

```bash
cat ~/.ssh/id_ed25519.pub | clip
```

## 第七步：把公钥添加到 GitHub

接下来去 GitHub 网页操作。

路径是：

- 右上角头像
- `Settings`
- `SSH and GPG keys`
- 点击 `New SSH key` 或 `Add SSH key`

然后：

### Title
这里建议写一个你自己能认出来的名字，比如：

- `My Laptop`
- `Workstation`
- `Cloud Server`

### Key
把刚才复制好的整行公钥粘进去。

然后点击添加即可。

## 第八步：测试 GitHub SSH 是否生效

GitHub 官方推荐用这条命令测试：

```bash
ssh -T git@github.com
```

第一次连接时，通常会问你要不要信任 GitHub 主机指纹，输入：

```text
yes
```

如果一切正常，你会看到类似：

```text
Hi your-username! You've successfully authenticated, but GitHub does not provide shell access.
```

这里最后一句很重要：

- GitHub 允许你通过 SSH 做 Git 认证
- 但它不会给你真正的 shell

所以看到这句话其实就是成功了。

## 第九步：把仓库远程地址切到 SSH

如果你现在的仓库还是 HTTPS 地址，需要改成 SSH 才能真正用上刚配置好的 key。

先看当前远程地址：

```bash
git remote -v
```

如果你看到的是这种：

```text
https://github.com/owner/repo.git
```

那就说明现在还在走 HTTPS。

把它改成 SSH：

```bash
git remote set-url origin git@github.com:owner/repo.git
```

然后再看一遍：

```bash
git remote -v
```

如果变成：

```text
git@github.com:owner/repo.git
```

就说明已经切过来了。

## 第十步：实际验证一次 Git push

前面都配完以后，最好还是实际跑一次 Git 命令验证一下。

例如：

```bash
git pull
git push
```

如果不再要求你重新走 HTTPS 认证，而是直接通过 SSH 工作，那就说明这套配置已经真正接通了。

## 常见问题 1：为什么我明明加了 key，还是报 permission denied

最常见的排查方向通常是这几个：

### 1）你加错文件了

加到 GitHub 的应该是：

- `.pub` 公钥

加到 `ssh-agent` 的应该是：

- 私钥

这两个别反过来。

### 2）你本地 Git 远程地址还在走 HTTPS

这个特别常见。

你 key 配好了，但仓库远程地址还是：

```text
https://github.com/...
```

那 Git 当然不会用 SSH。

### 3）`~/.ssh/config` 指向的不是你真正那把 key

如果你机器上有多把 key，就更容易出现这个问题。

### 4）ssh-agent 没启动，或者私钥没加进去

可以先看看当前 agent 里有哪些 key：

```bash
ssh-add -l
```

## 常见问题 2：我已经有服务器登录用的 SSH key，还要不要再建一把 GitHub 专用 key

这取决于你自己的习惯。

### 可以共用
如果你很确定自己知道在做什么，而且配置也简单，共用也不是不行。

### 也可以分开
但从管理角度来说，我其实更推荐：

- 服务器登录一套
- GitHub 访问一套

这样以后排查问题、换设备、撤销权限都会更清楚。

尤其是你开始同时管理：

- GitHub
- 多台服务器
- 不同开发环境

分开通常会更舒服。

## 常见问题 3：能不能用 GitHub CLI 来加 SSH key

可以。GitHub 官方也支持通过 `gh` 来处理 SSH key。

如果你已经登录过 GitHub CLI，那么这一步其实会更方便一些。

### 先确认 gh 已登录

```bash
gh auth status
```

如果还没登录，可以先执行：

```bash
gh auth login
```

### 用 gh 直接添加 SSH 公钥

如果你使用的是默认公钥文件：

```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --title "My Laptop"
```

如果你的 key 文件名不是默认的，就把路径换成你自己的 `.pub` 文件。

这个命令做的事情，本质上和你手工去 GitHub 网页：

- 打开 `Settings`
- 进入 `SSH and GPG keys`
- 点击 `New SSH key`
- 粘贴公钥

是一样的，只不过现在变成了命令行完成。

### 如果这里报权限不够怎么办

实际操作时，有一种情况挺常见：

你明明已经登录了 `gh`，但执行：

```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --title "My Laptop"
```

还是可能报类似这样的提示：

```text
This API operation needs the "admin:public_key" scope.
To request it, run: gh auth refresh -h github.com -s admin:public_key
```

这通常不是 SSH key 本身有问题，而是：

> **你当前 GitHub CLI 登录使用的 token 权限不够，缺少管理 SSH 公钥所需的 scope。**

这时候按提示补授权就行：

```bash
gh auth refresh -h github.com -s admin:public_key
```

完成授权以后，再重新执行：

```bash
gh ssh-key add ~/.ssh/id_ed25519.pub --title "My Laptop"
```

一般就能成功。

### 怎么确认是不是已经加上了

加完以后，你还是可以继续用这条命令测试：

```bash
ssh -T git@github.com
```

如果认证成功，说明这把 key 已经能正常给 GitHub 用了。

不过从“第一次配置”的角度来说，我还是觉得网页路径对很多人更直观：

- 先生成 key
- 复制公钥
- 粘贴到 GitHub 设置页

至少第一次配的时候，不容易迷糊。

## 写在最后

如果把这件事压缩成一句话，其实就是：

> **生成 SSH key，把公钥加到 GitHub，把本地仓库远程地址切到 SSH，然后测试是否认证成功。**

真正容易卡人的地方通常不是步骤本身，而是：

- 分不清公钥和私钥
- 不知道 Git 远程地址还在走 HTTPS
- 机器上有多把 key，结果配混了

所以你如果想尽量少踩坑，我会建议按这个顺序来：

1. 先确认有没有现成 key
2. 没有就生成 `ed25519`
3. 启动 `ssh-agent` 并加私钥
4. 配 `~/.ssh/config`
5. 把公钥加到 GitHub
6. 用 `ssh -T git@github.com` 测
7. 把仓库 remote 切到 SSH

这样一轮走下来，后面 GitHub 走 SSH 基本就稳了。