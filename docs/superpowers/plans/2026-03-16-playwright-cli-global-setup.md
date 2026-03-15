# Playwright CLI Global Setup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install Playwright CLI globally with `pnpm` and make its skills available to OpenCode without disturbing the existing Playwright MCP setup.

**Architecture:** Keep MCP and CLI side by side. Use `pnpm add -g` for the binary, then let `playwright-cli install --skills` place the skill files into the global agent skill location so OpenCode can discover them.

**Tech Stack:** pnpm global packages, Playwright CLI, OpenCode skill directories

---

## Chunk 1: Install and verify

### Task 1: Global Playwright CLI setup

**Files:**
- Verify: `/home/yangyus8/.config/opencode/skills`
- Verify: global `pnpm` package location

- [ ] **Step 1: Inspect the global package manager state**

Run: `pnpm root -g && pnpm bin -g && pnpm list -g --depth 0`
Expected: confirm global install location and whether `@playwright/cli` is already present.

- [ ] **Step 2: Install Playwright CLI globally with pnpm**

Run: `pnpm add -g @playwright/cli@latest`
Expected: `playwright-cli` becomes available on PATH.

- [ ] **Step 3: Install Playwright CLI skills**

Run: `playwright-cli install --skills`
Expected: skill files are installed into an OpenCode-discoverable global skill directory.

- [ ] **Step 4: Verify the binary and skills**

Run: `playwright-cli --help`
Expected: CLI help output appears.

Run: inspect `~/.config/opencode/skills/` and/or related installed paths
Expected: Playwright CLI skill files are present without removing existing `superpowers`.

- [ ] **Step 5: Keep MCP untouched**

Run: `opencode mcp list`
Expected: existing `playwright` and `playwright_debug` MCP entries still show as connected.
