# Playwright MCP Blog Post Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new Chinese blog post that records the process of installing and refining Playwright MCP for OpenCode on CachyOS.

**Architecture:** Create a new post in the existing `src/content/posts/` structure, using the repo's normal Chinese directory naming pattern. The article should read like a personal setup log: official docs first, then actual local configuration, then the decision to split into `playwright` and `playwright_debug`.

**Tech Stack:** Markdown content, Fuwari post frontmatter, GitHub repo embeds

---

## Chunk 1: Post creation and draft

### Task 1: Create the article scaffold

**Files:**
- Create: `src/content/posts/<date>-<chinese-title>/index.md`

- [ ] **Step 1: Create a new post with `pnpm new-post`**

Run: `pnpm new-post "给 OpenCode 接上 Playwright MCP 之后，我为什么又拆成了轻量版和调试版"`
Expected: a new `index.md` is created under `src/content/posts/`.

- [ ] **Step 2: Keep the generated Chinese directory name**

Do not convert the post folder into pinyin. Follow the naming pattern used by the other posts in this repo.

### Task 2: Write the article

**Files:**
- Modify: `src/content/posts/<date>-<chinese-title>/index.md`

- [ ] **Step 1: Update frontmatter**

Set a concise title, summary, tags, category, and `lang: 'zh_CN'`.

- [ ] **Step 2: Write the body in first-person practical style**

Cover:
- why browser automation mattered after the earlier OpenCode skill setup
- what OpenCode docs and Playwright MCP README say
- the first headless config that was actually added
- how it was verified with `opencode mcp list` and `opencode run`
- why a single debug-heavy config was not ideal for daily use
- why the final shape became `playwright` + `playwright_debug`

- [ ] **Step 3: Use repo embeds where natural**

Include GitHub cards for repos such as `microsoft/playwright-mcp` where helpful.

### Task 3: Final review

**Files:**
- Review: `src/content/posts/<date>-<chinese-title>/index.md`

- [ ] **Step 1: Review tone and structure**

Make sure it reads like a human-written setup note rather than a product summary.

- [ ] **Step 2: Review metadata and references**

Check title length, description clarity, Chinese directory naming, and command examples.
