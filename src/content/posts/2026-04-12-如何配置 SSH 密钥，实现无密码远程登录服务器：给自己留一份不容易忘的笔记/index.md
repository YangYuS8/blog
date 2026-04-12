---
title: "如何配置 SSH 密钥，实现无密码远程登录服务器：给自己留一份不容易忘的笔记"
urlSlug: '20260412-03'
published: 2026-04-12
description: '一篇写给自己的 SSH 免密登录备忘：从生成密钥、拷贝公钥到服务器，到最后验证无密码登录是否成功，尽量按最省事的顺序讲清楚。'
image: ''
tags: ['SSH', 'Linux', '服务器', '安全', '运维', '教程']
category: '软件教程'
draft: false 
lang: 'zh_CN'
---

有些东西看起来很基础，但只要隔一段时间不配，就真的容易忘。

SSH 密钥登录就是很典型的一类。

平时要连服务器时，如果每次都输入密码：

- 麻烦
- 慢
- 容易出错
- 也不够优雅

而且一旦你后面开始做：

- Git 操作
- 自动化脚本
- 远程部署
- 多台机器管理

SSH 免密登录几乎就是必备项了。

所以这篇文章我不打算讲太多抽象概念，主要是按“自己下次别忘了”的思路，把最常用的一套流程记下来。

## SSH 密钥登录到底是在做什么

先用最简单的话说：

**你本地保存一把私钥，把对应的公钥放到服务器上。**

之后你登录服务器时：

- 服务器用公钥确认你是不是对应私钥的持有者
- 如果匹配，就允许登录
- 你就不用每次再手动输密码

这里最重要的一点是：

- **私钥留在你自己电脑上**
- **公钥可以放到服务器上**

千万不要反过来。

## 第一步：先看自己有没有现成密钥

先在本地看一下：

```bash
ls -la ~/.ssh
```

如果你已经看到类似这些文件：

- `id_ed25519`
- `id_ed25519.pub`
- `id_rsa`
- `id_rsa.pub`

那说明你可能已经有密钥了。

一般来说，如果你没有特殊需求，优先用 `ed25519` 就够了。

## 第二步：如果没有，就生成一把新密钥

最常见的做法：

```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
```

执行后，它会问你：

- 保存到哪里
- 要不要设置 passphrase

如果你只是自己日常用，直接按默认路径通常就行：

```text
~/.ssh/id_ed25519
```

### 要不要设置 passphrase？

这个看你自己的习惯。

- **设 passphrase**：更安全
- **不设 passphrase**：更省事

如果你机器是自己独占使用，而且更重视方便，可以不设；如果你更在意私钥本地安全，建议设一个。

## 第三步：把公钥拷到服务器上

最省事的方式通常是：

```bash
ssh-copy-id root@你的服务器IP
```

例如：

```bash
ssh-copy-id root@192.168.3.16
```

它会做的事情其实就是：

- 读取你本地的公钥
- 登录到远程服务器
- 自动把公钥追加到远程的 `~/.ssh/authorized_keys`

第一次执行时，通常还需要你输入一次服务器密码。

输完以后，这一步基本就完成了。

## 如果没有 `ssh-copy-id` 怎么办

有些系统没有这个命令，那就手动来。

### 先查看公钥内容

```bash
cat ~/.ssh/id_ed25519.pub
```

会看到一长串类似这样的内容：

```text
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...... your_email@example.com
```

### 然后登录服务器，确保目录和权限正常

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

### 再把公钥追加进去

```bash
echo '这里换成你的公钥内容' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

这样也能完成配置。

## 第四步：测试是否已经能免密登录

配置完以后，直接重新连一次：

```bash
ssh root@192.168.3.16
```

如果一切正常，你应该会看到：

- 不再要求输入服务器密码
- 或者只要求输入本地私钥的 passphrase（如果你设置了）

这就说明 SSH 密钥登录已经生效了。

## 最常见的失败原因

如果你发现还是要输密码，通常优先检查这几项。

### 1）你拷错了公钥

最容易犯的错误之一就是：

- 把私钥内容当成公钥处理
- 或者把错误的 `.pub` 文件传上去了

记住：

- 公钥通常是 `*.pub`
- 私钥通常没有 `.pub`

## 2）服务器上的权限不对

SSH 对权限很敏感。

一般至少要保证：

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

如果权限太宽松，有些 SSH 服务端会直接拒绝使用这个文件。

## 3）登录的用户不对

你把公钥加到了 `root` 的 `authorized_keys` 里，却用别的用户去登录，那肯定不会生效。

所以要确认：

- 公钥加给谁
- SSH 连的是谁

这两个要一致。

## 4）服务器禁用了公钥登录

可以在服务器上检查 `/etc/ssh/sshd_config` 里这些配置：

```text
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

如果公钥登录被关掉了，那你本地配得再对也没用。

改完以后别忘了重载或重启 ssh 服务，例如：

```bash
systemctl restart ssh
```

或者有些系统是：

```bash
systemctl restart sshd
```

## 第五步：如果你要更安全一点

当你确认密钥登录正常之后，可以考虑下一步再做：

- 禁止密码登录
- 只保留密钥登录

这一步能明显提升安全性，但前提是：

**你已经确认自己真的能用密钥登录。**

否则一旦手滑，很容易把自己锁在服务器外面。

### 常见配置思路

在 `/etc/ssh/sshd_config` 里把：

```text
PasswordAuthentication no
```

再重启 SSH 服务。

但这一步我建议永远放在最后做，而且最好先留一个已登录会话别关，确认新会话能进，再决定是否完全切掉密码登录。

## 如果你有多台机器，`~/.ssh/config` 会非常省事

如果你要管理多台服务器，我很建议把 `~/.ssh/config` 用起来。

它的作用很简单：

- 给远程主机起一个短名字
- 顺手把用户名、端口、密钥文件都写进去
- 以后直接用一个短命令登录

例如：

```text
Host pve
    HostName 192.168.3.16
    User root
    IdentityFile ~/.ssh/id_ed25519

Host vps
    HostName your.server.ip
    User root
    IdentityFile ~/.ssh/id_ed25519
```

这样以后就能直接：

```bash
ssh pve
ssh vps
```

不用每次都敲完整地址。

### `~/.ssh/config` 文件放在哪里

位置就是：

```bash
~/.ssh/config
```

如果没有这个文件，可以自己创建：

```bash
touch ~/.ssh/config
chmod 600 ~/.ssh/config
```

## 最常用的几个配置项

对大多数人来说，先记住下面这些就够了。

### `Host`
这是你给这台机器起的别名。

例如：

```text
Host pve
```

那以后你就可以直接：

```bash
ssh pve
```

### `HostName`
这是服务器的真实地址，可以是：

- IP
- 域名

例如：

```text
HostName 192.168.3.16
```

### `User`
指定默认登录用户。

例如：

```text
User root
```

### `Port`
如果这台机器的 SSH 不是默认 22 端口，就可以写：

```text
Port 2222
```

### `IdentityFile`
指定用哪把私钥。

例如：

```text
IdentityFile ~/.ssh/id_ed25519
```

这在你有多把密钥时尤其有用。

## 一个更完整一点的例子

```text
Host pve
    HostName 192.168.3.16
    User root
    Port 22
    IdentityFile ~/.ssh/id_ed25519

Host blog-vps
    HostName your.server.ip
    User root
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

以后你就可以这样用：

```bash
ssh pve
ssh blog-vps
```

## `~/.ssh/config` 还有什么好处

除了省得你反复敲地址，它还有几个很实用的点：

- 多台机器不会记混
- 不同服务器可以指定不同密钥
- 自定义端口时不用每次加 `-p`
- 后面配 `scp`、`rsync`、Git SSH 时也会更顺手

例如：

```bash
scp file.txt pve:/root/
rsync -av ./project blog-vps:/srv/project
```

这时候别名也一样能直接用。

## 我自己更推荐的顺序

如果下次我自己再配一次，我会按这个顺序走：

1. `ssh-keygen -t ed25519`
2. `ssh-copy-id user@host`
3. `ssh user@host` 测试一次
4. 确认正常后，再考虑禁用密码登录
5. 最后再配 `~/.ssh/config`

这条路径最省事，也最不容易把自己绕进去。

## 写在最后

SSH 密钥登录这件事，说复杂不复杂，但它特别像一种“隔段时间就会忘细节”的操作。

所以真正有用的不是记住一堆原理，而是记住最常用的那条路径：

- 生成密钥
- 拷贝公钥
- 测试登录
- 再考虑关密码

如果你只记得这一条，以后大多数服务器的免密登录配置都够用了。
