# Playwright CLI Blog Post Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new Chinese blog post that records the process of installing Playwright CLI with `pnpm`, discovering its workspace-oriented skill install behavior, and moving the skill into a true global OpenCode directory.

**Architecture:** Create a standalone post under `src/content/posts/` with a Chinese directory name, following the tone of the prior OpenCode setup posts. The article should center on the real-world setup path: global CLI install, unexpected workspace skill placement, then manual migration into `~/.config/opencode/skills/`.

**Tech Stack:** Markdown content, Fuwari post frontmatter, GitHub repo embeds

---

## Chunk 1: Post creation and draft

### Task 1: Create the post scaffold

**Files:**
- Create: `src/content/posts/<date>-<chinese-title>/index.md`

- [ ] **Step 1: Create a new post with `pnpm new-post`**

Run: `pnpm new-post "在 CachyOS 上给 OpenCode 接 Playwright CLI：为什么我又手动搬了一次 skill"`
Expected: a new post directory and `index.md` are created under `src/content/posts/`.

- [ ] **Step 2: Keep the generated Chinese directory name**

Do not convert the post folder to pinyin.

### Task 2: Write the article

**Files:**
- Modify: `src/content/posts/<date>-<chinese-title>/index.md`

- [ ] **Step 1: Update frontmatter**

Set the title, description, tags, category, and `lang: 'zh_CN'`.

- [ ] **Step 2: Write the body in first-person practical style**

Cover:
- why Playwright CLI became interesting after setting up MCP
- what the official Playwright CLI README says about coding agent workflows
- why `pnpm` global install was chosen
- what happened when `playwright-cli install --skills` put files into `.claude/skills/`
- why that result was usable but not clean enough
- how the skill was moved into a truly global OpenCode directory
- what verification commands proved the final state

- [ ] **Step 3: Use repo embeds where natural**

Include a GitHub card for `microsoft/playwright-cli`.

### Task 3: Final review

**Files:**
- Review: `src/content/posts/<date>-<chinese-title>/index.md`

- [ ] **Step 1: Review tone and structure**

Make sure it reads like a setup log rather than product documentation.

- [ ] **Step 2: Review metadata and references**

Check title length, directory naming, GitHub embed usage, and command examples.
