# Playwright Dual Profile Config Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expose both a lightweight default Playwright MCP profile and a heavier debugging profile in OpenCode.

**Architecture:** Keep both profiles in the same `opencode.json` file so switching happens at prompt time, not by editing config. The lightweight profile keeps startup cost and artifacts low, while the debug profile keeps trace, session, devtools, and broader timeouts for harder investigations.

**Tech Stack:** OpenCode config, Playwright MCP, local MCP server commands

---

## Chunk 1: Dual MCP entries

### Task 1: Split the single Playwright config into light and debug profiles

**Files:**
- Modify: `/home/yangyus8/.config/opencode/opencode.json`
- Verify: `opencode mcp list`

- [ ] **Step 1: Replace the current `playwright` entry with a lightweight default**

Use a minimal command that keeps `headless`, a fixed output dir, and conservative timeouts, but removes debug-heavy capabilities like saved session and devtools.

- [ ] **Step 2: Add a new `playwright_debug` entry**

Use the current debug-oriented arguments: `--caps devtools`, `--console-level info`, `--output-mode file`, `--save-session`, `--save-trace`, larger timeouts, and a desktop viewport.

- [ ] **Step 3: Verify both entries are registered**

Run: `opencode mcp list`
Expected: both `playwright` and `playwright_debug` appear as connected.

- [ ] **Step 4: Confirm intended usage model**

Default prompts should use `playwright`. Complex investigation prompts should explicitly say `use playwright_debug`.
