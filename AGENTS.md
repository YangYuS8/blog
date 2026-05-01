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
- generate a sequential `urlSlug`
- avoid directory collisions

Do **not** invent `urlSlug` manually unless the user explicitly asks for a custom slug.

## 4. Frontmatter contract

At minimum, a post should include these fields:

```yaml
---
title:
urlSlug:
published:
description:
image:
tags:
category:
draft:
lang:
---
```

Notes:

- Default language is usually `zh_CN`
- `draft` is usually `false` unless the user explicitly wants a draft
- `description` should be meaningful, not placeholder text
- `tags` should be specific and helpful for archive/search views
- `category` should be short and consistent with existing posts

The actual schema lives in `src/content/config.ts`; do not introduce fields that are not supported there unless the schema is updated too.

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

Avoid:

- fake certainty
- inflated claims
- generic “best practices” with no context
- pretending a step was executed if it was not
- fabricated logs, commands, or results

If critical information is missing, explicitly mark it as something the user needs to confirm or provide.

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
