# AGENTS.md — YangYuS8/blog

This repository is a personal technical blog based on Astro + Fuwari. If you are an AI coding/writing agent working in this repo, follow the rules below before making changes.

## 1. Project purpose

This is not a generic template repo anymore. It is the source for **杨与S8的博客**:

- Site: `https://blog.yangyus8.top/`
- Main language: Simplified Chinese
- Primary content type: personal technical practice notes, troubleshooting writeups, beginner-friendly tutorials, and hands-on DevOps / Linux / AI agent workflow posts.

The writing should feel like a real engineering diary with clear operational value, not like anonymous marketing copy or empty documentation.

## 2. Stack and important paths

- Framework: Astro + Fuwari
- Package manager: `pnpm`
- Post content: `src/content/posts/`
- Post schema: `src/content/config.ts`
- Site config: `src/config.ts`
- RSS endpoint source: `src/pages/rss.xml.ts`
- New-post generator: `scripts/new-post.js`
- Deployment workflow: `.github/workflows/deploy.yml`

Typical post layout:

- one directory per post
- each post directory contains `index.md`
- directory names should match the current display title: `YYYY-MM-DD-短标题`
- keep `urlSlug` stable unless the user explicitly asks for URL migration

Example:

`src/content/posts/2026-04-21-k3s 部署 Loki 与 Grafana Alloy/index.md`

## 3. Non-negotiable writing workflow

When creating a new post, **prefer the generator script** instead of hand-creating files:

```bash
pnpm new-post "文章标题"
```

This script will:

- create a dated directory under `src/content/posts/`
- create `index.md`
- generate a human-readable kebab-case `urlSlug` from the title by default
- avoid `urlSlug` and directory collisions

For SEO and readability, post URLs should be meaningful slugs, not pure date/sequence IDs.

Preferred examples:

- `k3s-loki-grafana-log-query-guide`
- `opencode-project-skills-grade-workflow`
- `headscale-fedora-dns-latency-fix`

Avoid:

- `20260421-02`
- `post-1`
- opaque internal IDs

If the title is Chinese or otherwise cannot produce a clear ASCII slug, pass an explicit slug:

```bash
pnpm new-post "文章标题" --slug meaningful-english-kebab-slug
```

If the post is written by someone other than the site owner, pass an explicit author:

```bash
pnpm new-post "文章标题" --slug meaningful-slug --author "Sakurakouji Luna"
```

Do **not** reintroduce date-only `urlSlug` values unless the user explicitly asks for an archival compatibility experiment.

## 4. Frontmatter contract

At minimum, a post should include these fields:

```yaml
---
title:
urlSlug:
published:
description:
image:
author:
tags:
category:
draft:
lang:
---
```

Notes:

- Default language is usually `zh_CN`
- `draft` is usually `false` unless the user explicitly wants a draft
- `author` may be empty for the site owner; set it explicitly for guest/agent-authored posts
- `description` should be meaningful, not placeholder text
- `tags` should be specific and helpful for archive/search views
- `category` should be short and consistent with existing posts

The actual schema lives in `src/content/config.ts`; do not introduce fields that are not supported there unless the schema is updated too.


## 4.1 Category and tag taxonomy

Keep `category` narrow and stable. Use exactly one of these categories for normal posts:

- `建站与内容系统` — Astro/Fuwari, blog workflow, URL/SEO/content plumbing
- `Linux 与开发环境` — Linux desktop/server environment, shell, editors, package/runtime issues
- `云原生与容器` — Docker, Docker Compose, Kubernetes, k3s, kind, Helm basics
- `监控与日志` — Prometheus, Grafana, Loki, EFK/ELK, Zabbix, observability
- `网络与代理` — DNS, proxy tools, Clash/FlClash, Tailscale/Headscale, VPN/routing
- `AI Agent 工作流` — OpenCode, OpenClaw, Hermes, skills, MCP/ACP, coding-agent workflows
- `DevOps 自动化与工程实践` — Ansible, Terraform, IaC, systemd, SSH, Git, interview/practice tasks

Do not use broad buckets such as `软件教程`, `问题排查`, `编程实践`, `系统折腾`, `运维实践`, or `日记` as categories for new posts. Use tags like `故障排查`, `新手教程`, `实战记录`, or `日记` instead.

Tag rules:

- Keep official capitalization for technical names: `OpenCode`, `OpenClaw`, `Kubernetes`, `Docker`, `GitHub`, `Tailscale`, `Headscale`, `Node.js`, `systemd`.
- Use `Kubernetes`, not `k8s`/`kubernetes`; use `OpenCode`, not `opencode`; use `Shell`, not `shell`.
- Use `故障排查` for troubleshooting posts, not `问题排查`.
- Use `新手教程` for beginner tutorials, not `教程`/`使用教程`/`新手指南`/`新手向`.
- Prefer 4–7 tags per post: core technology tags plus one scenario tag when useful.

## 5. Blog voice and structure

The target style is inspired by `wiki.eryajf.net`: practical personal knowledge-base writing for ops/devops readers. Learn the structure and usefulness, not the exact wording.

Core principles:

1. **Title first, story second.** Titles should name the technology and task directly. Avoid long conversational titles such as “为什么我最后……”, “我是怎么……”, or “给自己留一份……”.
2. **One article, one operational goal.** The reader should know what they can finish after reading: install, deploy, configure, troubleshoot, compare, or review.
3. **Short opening.** Start with the goal, environment, and conclusion. Do not spend several paragraphs setting the mood.
4. **Step-by-step body.** Prefer numbered stages, explicit commands, expected output, screenshots/UI anchors when useful, and verification steps.
5. **Real experience, not diary chatter.** Personal notes are allowed when they explain a tradeoff or pitfall. Remove chatty transitions that do not help the reader act.
6. **Keep uncertainty honest.** If a command, version, or production claim was not verified, say so. Do not invent logs or results.

Recommended structures:

### Tutorial / setup post

1. `目标`
2. `环境`
3. `准备工作`
4. `安装 / 配置 / 部署` with numbered steps
5. `验证`
6. `常见问题`
7. `总结`

### Troubleshooting post

1. `现象`
2. `环境`
3. `排查过程`
4. `根因`
5. `修复`
6. `验证`
7. `总结`

### Concept / comparison post

1. `结论`
2. `概念`
3. `差异`
4. `适用场景`
5. `选择建议`
6. `总结`

### Practice / project post

1. `目标`
2. `环境与目录`
3. `实施步骤`
4. `验证方式`
5. `踩坑记录`
6. `总结`

Title rules:

- Prefer 8–24 Chinese characters when possible. Long technical names are allowed, but remove rhetorical tails.
- Good: `k3s 部署 Loki 与 Grafana Alloy`, `GitHub SSH 密钥配置`, `Headscale DNS 接管排查`.
- Avoid: `为什么我的 xxx 总装不上：从 xxx 到 xxx 的排查记录`, `我是怎么一步步 xxx`, `给自己留一份不容易忘的笔记`.
- Keep `urlSlug` stable unless the user explicitly asks for URL migration.

Heading rules:

- Use direct nouns or tasks: `环境`, `安装 Helm`, `配置 values`, `验证结果`, `根因`, `修复方式`.
- Avoid filler headings: `先说一句`, `真正让我意识到`, `回头看`, `写在最后`, `最后的结论`.
- Do not overuse “为什么”. Use it only when the section is genuinely explaining cause.

Tone:

- Calm, practical, direct.
- Beginner-friendly without pretending the reader knows nothing.
- Prefer commands and verification over persuasion.
- No marketing tone, no fake “最佳实践”, no generic inspirational endings.
- Luna-authored diary posts are exempt from this strict tutorial style; keep their frontmatter/category valid, but allow Luna’s voice.

## 7. Editing rules for agents

Before editing:

```bash
git status
git diff
```

After editing, validate with the smallest reasonable scope first, then broader checks as needed:

```bash
pnpm check
pnpm lint
pnpm build
```

If dependencies are not installed yet:

```bash
pnpm install
```

Do not push directly to `main` unless the user explicitly requests it.

## 8. README / automation notes

The repository README is allowed to be more functional than minimal. It can include:

- project overview
- local development commands
- writing workflow summary
- RSS / latest-post automation blocks
- deployment notes

If updating the auto-generated latest-post section, preserve the comment markers exactly:

```html
<!-- BLOG-POST-LIST:START -->
<!-- BLOG-POST-LIST:END -->
```

## 9. Commit guidance

Suggested commit styles:

- `docs: add xxx post`
- `docs: update README`
- `docs: add agent collaboration guide`
- `chore: update blog post workflow`

Keep commits scoped and descriptive.

## 10. Agent checklist before handoff

Before handing work back to the user, confirm:

- the post or doc matches repository style
- frontmatter is valid
- paths and commands are correct
- no unsupported schema fields were added
- generated/automated sections are still syntactically valid
- `git diff` is readable and intentional

When in doubt, optimize for accuracy and maintainability over cleverness.
