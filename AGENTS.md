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

Example:

`src/content/posts/2026-04-21-如何在 k3s 里部署和使用 Loki：按官方当前推荐路线完成一次最小可用实践/index.md`

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

## 5. Expected article structure

Most posts in this repo work best with a practical structure like this:

1. Problem background / why this topic matters
2. Environment or prerequisite context
3. Real troubleshooting or implementation process
4. Root cause / concept explanation
5. Final solution or recommended approach
6. Review / lessons learned

Good posts in this repo usually optimize for:

- clear reasoning
- executable commands
- honest tradeoffs
- realistic troubleshooting steps
- beginner readability without oversimplifying the technical truth

## 6. Tone and style

Match the repository’s existing tone:

- calm, practical, and direct
- personal but not overly casual
- explanatory, especially for beginners
- grounded in real actions and real outcomes

The user's current preferred blog style is more specific than the older posts may suggest:

- concise and tutorial-oriented
- short paragraphs
- direct headings that state the task/platform clearly
- step-by-step operational writing
- screenshot-led explanations where images carry part of the tutorial flow
- minimal filler, minimal scene-setting, minimal rhetorical transitions
- personal remarks only when clearly marked as reference, preference, or caveat

Prefer structures like:

1. direct topic statement
2. prerequisites / what to prepare
3. step-by-step actions
4. screenshots or UI anchors
5. brief FAQ / troubleshooting
6. short operational summary

Prefer wording that helps the reader act immediately. Optimize for:

- what to click
- what to download
- what to enable
- what to verify
- what to check when it fails

Avoid:

- fake certainty
- inflated claims
- generic “best practices” with no context
- pretending a step was executed if it was not
- fabricated logs, commands, or results
- long titles with conversational framing
- chatty/meta sections like “先说一句实话”, “这篇怎么用”, “最后想说一句”
- explanatory filler such as “为什么常见 / 主要在考什么 / 你做的时候要注意” unless the user explicitly asks for that format
- emotional or persuasive copy when a tutorial step would do

If critical information is missing, explicitly mark it as something the user needs to confirm or provide.

When unsure, make the article read more like a usable walkthrough and less like an AI answer.

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
