# 杨与S8的博客

[![Site](https://img.shields.io/badge/site-online-6f42c1?style=flat-square&logo=astro)](https://blog.yangyus8.top/)
[![RSS](https://img.shields.io/badge/rss-subscribe-orange?style=flat-square&logo=rss)](https://blog.yangyus8.top/rss.xml)
[![Deploy](https://github.com/YangYuS8/blog/actions/workflows/deploy.yml/badge.svg)](https://github.com/YangYuS8/blog/actions/workflows/deploy.yml)
![Astro](https://img.shields.io/badge/Astro-5.x-ff5d01?style=flat-square&logo=astro)
![pnpm](https://img.shields.io/badge/pnpm-9.x-f69220?style=flat-square&logo=pnpm)
![License](https://img.shields.io/badge/content-CC%20BY--NC--SA%204.0-blue?style=flat-square)

这是我的个人技术博客仓库。

这里主要写：

- Linux / Shell / Git / SSH 折腾记录
- Kubernetes / k3s / Helm / 监控 / 日志实践
- Ansible / Terraform / DevOps 入门与实战
- OpenCode / Hermes / skills / agent 工作流排障与经验
- 面向新手、但尽量保持技术准确性的教程与复盘

## 这个仓库是什么

这个仓库已经不只是一个博客模板，而是 **杨与S8的博客** 的真实内容源。

- 在线地址：<https://blog.yangyus8.top/>
- RSS：<https://blog.yangyus8.top/rss.xml>
- 站点技术栈：Astro + Fuwari + Tailwind + Svelte
- 写作语言：以 `zh_CN` 为主

如果你是协作者，或者是准备在这里帮我改文章 / 改配置 / 改文档的 agent，建议先看：

- `AGENTS.md`：面向 agent 的协作约定
- `.hermes.md`：Hermes 项目规则
- `src/content/config.ts`：文章 schema
- `src/config.ts`：站点配置

---

## 仓库结构

```text
.
├── AGENTS.md
├── README.md
├── src/
│   ├── config.ts
│   ├── content/
│   │   ├── config.ts
│   │   └── posts/
│   │       └── <date-title>/index.md
│   └── pages/
├── scripts/
│   └── new-post.js
└── .github/workflows/
    ├── deploy.yml
    └── blog-post-workflow.yml
```

关键路径：

- `src/content/posts/`：文章内容
- `src/content/config.ts`：文章 schema
- `src/config.ts`：站点设置
- `src/pages/rss.xml.ts`：RSS 生成逻辑
- `scripts/new-post.js`：新文章脚本
- `.github/workflows/deploy.yml`：部署工作流
- `.github/workflows/blog-post-workflow.yml`：README 最新文章同步

---

## 本地开发

### 安装依赖

```bash
pnpm install
```

### 启动开发环境

```bash
pnpm dev
```

默认地址：`http://localhost:4321`

### 创建新文章

```bash
pnpm new-post "文章标题"
```

这个命令会自动：

- 在 `src/content/posts/` 下创建日期目录
- 生成 `index.md`
- 自动生成 `urlSlug`
- 避免重复目录冲突

### 检查与构建

```bash
pnpm check
pnpm lint
pnpm build
```

---

## 写作方式

这个博客比较偏 **个人技术实践记录**，通常适合这样的结构：

1. 问题背景
2. 环境信息 / 前置条件
3. 排查或实现过程
4. 根因 / 原理解释
5. 最终方案
6. 复盘与经验总结

我更希望文章：

- 说人话，但不牺牲准确性
- 不只是给结论，也讲清“为什么”
- 贴近真实操作过程
- 命令尽量可直接执行
- 不编造没发生过的步骤

如果你是 agent，默认也请按这个方向写。

---

## Frontmatter 约定

文章至少应包含这些字段：

```yaml
---
title: "文章标题"
urlSlug: '20260421-01'
published: 2026-04-21
description: '一句简洁准确的摘要'
image: ''
tags: ['示例标签']
category: '编程实践'
draft: false
lang: 'zh_CN'
---
```

真实 schema 以 `src/content/config.ts` 为准。

---

## 最新文章

这个区块会通过 [gautamkrishnar/blog-post-workflow](https://github.com/gautamkrishnar/blog-post-workflow) 从站点 RSS 自动更新。

<!-- BLOG-POST-LIST:START -->
- 2026-04-21 · [如何在 k3s 里部署和使用 Loki：按官方当前推荐路线完成一次最小可用实践](https://blog.yangyus8.top/posts/20260421-02/)
- 2026-04-21 · [ELK、EFK 和 Loki 分别是什么：面向日志系统选型的一篇横向对比](https://blog.yangyus8.top/posts/20260421-01/)
- 2026-04-20 · [Helm 是什么，应该怎么安装和使用：给 Kubernetes 新手的一篇实战入门](https://blog.yangyus8.top/posts/20260420-02/)
- 2026-04-20 · [为什么我的 kube-prometheus-stack 总装不上：从 Helm 报错到 k3s 代理配置的排查记录](https://blog.yangyus8.top/posts/20260420-01/)
- 2026-04-18 · [Git SSH 密钥怎么配：从生成密钥到让 GitHub 走 SSH 的一份完整上手教程](https://blog.yangyus8.top/posts/20260418-01/)
<!-- BLOG-POST-LIST:END -->

---

## 自动化

### README 最新文章自动更新

仓库包含一个 GitHub Actions 工作流：

- `.github/workflows/blog-post-workflow.yml`

它会：

- 从 `https://blog.yangyus8.top/rss.xml` 读取最新文章
- 自动更新 README 里的“最新文章”区块
- 默认每天同步一次
- 支持手动触发 `workflow_dispatch`

如果你 fork 了这个仓库，记得：

1. 确认 RSS 地址仍然正确
2. 到 GitHub 仓库设置里开启 Actions 的 **Read and write permissions**
3. 手动运行一次 workflow，确认 README 能被正常更新

### 站点部署

当前部署通过 GitHub Actions 完成：

- push 到 `main`
- 安装依赖
- 执行 `pnpm build`
- 将 `dist/` 上传到服务器目录

部署工作流文件：

- `.github/workflows/deploy.yml`

---

## 协作建议

如果你是 agent：

- 先看 `AGENTS.md`
- 新文章优先用 `pnpm new-post "标题"`
- 不要随便手写 `urlSlug`
- 变更前后都看 `git diff`
- 除非明确要求，不要直接 push 到 `main`

---

## License

博客代码与主题定制部分遵循仓库自身约定；文章内容默认以站点内声明为准。当前页面版权信息参考站点配置中的：

- `CC BY-NC-SA 4.0`
