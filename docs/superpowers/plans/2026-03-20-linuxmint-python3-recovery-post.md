# Linux Mint Python3 Recovery Post Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create and publish a new Chinese troubleshooting post that turns the approved Linux Mint 22 Python3 recovery spec into a first-person blog article matching the repository's existing style.

**Architecture:** Use the repository's `pnpm new-post` scaffold to create a new article folder under `src/content/posts/`, then write the full post directly in the generated `index.md` using the approved time-line structure from the spec. Finish by running the project's content-safe verification commands so the post builds cleanly and uses valid frontmatter.

**Tech Stack:** pnpm, Node.js script scaffolding, Markdown frontmatter, Astro content collection

---

### Task 1: Create the post scaffold

**Files:**
- Create: `src/content/posts/<generated-post-dir>/index.md`
- Reference: `scripts/new-post.js`
- Reference: `docs/superpowers/specs/2026-03-20-linuxmint-python3-recovery-design.md`

**Source of truth:** Use only the commands, outputs, and ordering explicitly preserved in `docs/superpowers/specs/2026-03-20-linuxmint-python3-recovery-design.md`. Do not add unverified recovery steps from memory.

- [ ] **Step 1: Generate the new post skeleton**

Run: `pnpm new-post "Linux Mint 22 上 Python3 包管理崩掉之后，我是怎么一步步救回来的"`
Expected: a new folder appears under `src/content/posts/` with a generated `index.md`

- [ ] **Step 2: Inspect the generated path and frontmatter scaffold**

Read the new `src/content/posts/<generated-post-dir>/index.md` file.
Expected: frontmatter contains `title`, `urlSlug`, `published`, `description`, `image`, `tags`, `category`, `draft`, `lang`

- [ ] **Step 3: Update frontmatter fields for this article**

Set:

```md
description: '记录我在 Linux Mint 22 上排查 Python3 核心包损坏的过程：从 dpkg 状态异常、post-installation 脚本报错，到一步步把 python3 和相关依赖恢复到 ii。'
tags: ['Linux Mint', 'Python3', 'dpkg', 'apt', 'Linux', '故障排查']
category: '编程实践'
draft: false
lang: 'zh_CN'
```

Expected: frontmatter is complete and consistent with existing posts

### Task 2: Write the article body from the approved spec

**Files:**
- Modify: `src/content/posts/<generated-post-dir>/index.md`
- Reference: `docs/superpowers/specs/2026-03-20-linuxmint-python3-recovery-design.md`

- [ ] **Step 1: Write the opening and initial failure state**

Include the first-person setup, the `dpkg -l | grep python3` context, the exact abnormal package states from the source conversation, and an immediate explanation of the two key status markers:

- `rF` = removed, configuration failed
- `rU` = unpacked, not yet configured

- [ ] **Step 2: Write the standard recovery attempt section**

Include:

```bash
sudo dpkg --configure -a
sudo apt install -f
```

Explain why these were the correct first moves instead of speculative fixes.
Also explain the mechanism of each command:

- `sudo dpkg --configure -a` = retry unfinished package configuration scripts
- `sudo apt install -f` = repair broken dependency/install relationships

- [ ] **Step 3: Write the escalation section with exact error text**

Include the `post-installation` script failure and `E: Internal Error, No file name for python3:amd64`, then clearly separate observed facts from later technical suspicion.

- [ ] **Step 4: Write the “why I started suspecting core package state damage” section**

Explicitly cover:

- `python3` is a system-level base package
- `rF` + multiple `rU` states appearing together suggests an interrupted or broken install/configure state
- this is the point where the judgment upgraded from ordinary configure failure to likely package-state inconsistency

- [ ] **Step 5: Write the workaround and recovery sequence**

Include this exact sequence in article order:

```bash
sudo cp /var/lib/dpkg/info/python3.postinst /var/lib/dpkg/info/python3.postinst.bak
sudo bash -c 'echo -e "#!/bin/sh\nexit 0" > /var/lib/dpkg/info/python3.postinst'
sudo chmod +x /var/lib/dpkg/info/python3.postinst
sudo dpkg --configure python3
sudo dpkg --configure -a
sudo apt install -f
sudo apt install --reinstall python3 python3-minimal python3-apt python3-commandnotfound python3-gdbm command-not-found -y
sudo apt install -f -y
```

Also state explicitly that `E: Internal Error, No file name for python3:amd64` did not disappear immediately during the reinstall attempt, but the later `sudo apt install -f -y` still pushed the relevant packages back into a configurable state.

- [ ] **Step 6: Write the verification beats throughout the timeline**

Require these exact checkpoints in context:

- after `sudo dpkg --configure python3`, include `正在设置 python3 (3.12.3-0ubuntu2.1) ...`
- after `sudo apt install -f`, include `python3-gdbm:amd64` / `python3-apt` / `python3-commandnotfound` / `command-not-found` entering `正在设置 ...`
- explicitly explain `ri` = partial recovery and `ii` = full recovery
- include the final restored `dpkg -l | grep python3` examples with `ii  python3`, `ii  python3-apt`, `ii  python3-commandnotfound`, `ii  python3-gdbm:amd64`

- [ ] **Step 7: Write the failed side-path and final retrospective**

Mention the `py3clean` traceback branch, include the failed attempt to move `/usr/lib/python3/dist-packages/debpython/py3clean`, explain why that branch was abandoned, then close with 3 concise lessons learned in the same voice as recent posts.

### Task 3: Polish for repository style

**Files:**
- Modify: `src/content/posts/<generated-post-dir>/index.md`
- Reference: `src/content/posts/2026-03-16-在 CachyOS 上给 OpenCode 接 Playwright CLI：为什么我又手动搬了一次 skill/index.md`
- Reference: `src/content/posts/2026-03-18-从 Docker 到 Kubernetes：我在 Arch Linux 上搭起第一个 K8s 集群/index.md`

- [ ] **Step 1: Align tone with recent first-person troubleshooting posts**

Check that the article reads like a lived debugging record, not a sanitized how-to.

- [ ] **Step 2: Remove any unsupported certainty**

Ensure inferred root-cause language stays probabilistic unless directly proven by the source conversation.

- [ ] **Step 3: Tighten headings and transitions**

Make sure each section advances the debugging timeline and that no heading repeats the same idea.

### Task 4: Verify the new post

**Files:**
- Verify: `src/content/posts/<generated-post-dir>/index.md`

- [ ] **Step 1: Run Astro content/type checks**

Run: `pnpm check`
Expected: success with no content schema errors

- [ ] **Step 2: Run the production build**

Run: `pnpm build`
Expected: successful Astro build and Pagefind indexing

- [ ] **Step 3: Confirm final article path and status**

Run: `git status --short`
Expected: new post path is present in the working tree

- [ ] **Step 4: Run manual content QA against the spec**

Confirm all of the following before finishing:

- the timeline is complete and chronological
- the escalation from normal recovery to suspected core-package state damage is clearly visible
- commands and errors are contextualized instead of dumped raw
- the tone matches recent first-person troubleshooting posts in this repo
