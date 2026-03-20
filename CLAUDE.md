# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Format all Lua**: `stylua .`
- **Format single file**: `stylua <file.lua>`
- **No test runner** — this is a Neovim config; verify changes by opening Neovim and checking LSP diagnostics

## Code Style

From `.stylua.toml`: 120-char line width, 2-space indent, Unix line endings, double quotes preferred, no call parentheses (`call_parentheses = "None"`). However, existing files use 4-space indent — match whatever the file you're editing uses.

## Architecture

**Framework**: NvChad v2.5 (loaded as a Lazy plugin from `NvChad/NvChad`) on top of Lazy.nvim. NvChad provides base plugins, options, autocmds, and mappings — these live under `lua/nvchad/` and are treated as read-only upstream code.

**Entry point**: `init.lua` bootstraps Lazy, loads `{import = "plugins"}` (all files in `lua/plugins/`), then loads `options`, `commands/*`, and `mappings`.

**Config layers**:
- `lua/chadrc.lua` — NvChad overrides: theme (aquarium, transparent), statusline order/modules, tabufline
- `lua/options.lua` — Neovim option overrides
- `lua/mappings.lua` — all keymaps (extends `nvchad.mappings`)
- `lua/configs/` — plugin configs (lspconfig, conform, lazy settings)
- `lua/plugins/` — one file per plugin spec returned as a lazy.nvim table
- `lua/commands/` — custom user commands loaded at startup

## quarker (custom plugin)

The main custom plugin lives in `lua/quarker/`. It is loaded as a local Lazy plugin (`dir = vim.fn.stdpath("config") .. "/lua/quarker"`).

**What it does**: Per-repository file marking with named scopes. Marks are persisted as JSON in `~/.local/share/nvim/quarker/<sha256(git_root)>/<scope_name>.json`. Scope metadata (active scope, scope list) lives alongside in `scopes.json`.

**Module map**:
```
lua/quarker/
├── init.lua         — Public API + :Quarker command with tab-completion
├── ai.lua           — AI context generation (claude/cursor-agent/copilot CLI backends)
├── sync.lua         — Writes quarker context into CLAUDE.md / .cursor/rules/quarker.mdc / AGENT.md
├── context.lua      — Per-scope context document (read/write/export)
├── plan.lua         — Discovers task_plan.md files in the repo
├── telescope.lua    — Telescope pickers for marks and scopes
├── telescope_integration.lua — Enhanced find_files with marked-file sorting
└── ui/
    ├── init.lua     — Orchestrator: show_marks(), show_scopes(), show_context()
    ├── float.lua    — create_float_win(opts) — shared floating window factory
    ├── marks.lua    — Marks list panel
    ├── scopes.lua   — Scope manager panel
    ├── context.lua  — Context editor panel
    └── plan_panel.lua — Floating task_plan.md viewer
```

**Scope key format**: `"<git_root>:<scope_name>"` (e.g. `"/home/user/project:feature-x"`)

**sync.lua behaviour**: On scope switch and startup, `quarker.sync.sync()` injects the active scope's context between `<!-- quarker-context:start -->` / `<!-- quarker-context:end -->` markers into `CLAUDE.md` and/or `.cursor/rules/quarker.mdc`. **Do not manually edit between those markers** — changes will be overwritten on next sync.

**Statusline**: `require("quarker").statusline()` is called on every render; it caches for 200ms using `vim.loop.hrtime()`.

## Key patterns

- **Caching**: module-level `cache` table + `vim.loop.hrtime()` timestamps (e.g. 5s for git root, 500ms for marks, 200ms for statusline)
- **Persistence**: `vim.json.encode/decode` wrapped in `pcall`; always guard file reads with `vim.fn.filereadable()`
- **Floating windows**: use `create_float_win(opts)` from `quarker/ui/float.lua`
- **pcall guards**: use `pcall` for `sign_unplace`, buffer validity checks (`nvim_buf_is_valid`), and any scheduled callbacks that reference windows/buffers that may have been closed
- **Plugin specs**: each `lua/plugins/<name>.lua` returns a single table (or list of tables) for Lazy
- **NvChad statusline modules**: wrap `require` in `pcall` to avoid breaking the statusline if a plugin isn't loaded yet

<!-- quarker-context:start -->
## Quarker Active Scope

_Active scope: **quarker**_

## Overview
The `quarker` plugin's AI + context subsystem provides AI-assisted codebase context generation, storage, and plan tracking for Neovim development workflows. ✅
- **AI layer** (`ai.lua`): Detects available CLI AI backends, builds prompts from marked files, and runs async AI commands to generate/refresh context documents. ✅
- **Context layer** (`context.lua`): Persists AI-generated context as per-scope `.context.md` files keyed by SHA256 hash of the project root. ✅
- **Plan layer** (`plan.lua`): Discovers and parses `task_plan.md` checklists under `plans/` for a task panel UI. ✅
---
## Code Map
| File | Purpose |
|---|---|
| `lua/quarker/ai.lua` | Backend detection, prompt building, async AI execution, public commands (`generate_context`, `generate_feature_note`, `refresh_context`, `status`) ✅ |
| `lua/quarker/context.lua` | Read/write context markdown to `~/.local/share/nvim/quarker/<sha256>/`, clipboard export, rename/delete hooks ✅ |
| `lua/quarker/plan.lua` | Parse `task_plan.md` into phases/checklist items, discover plan files under `plans/` ✅ |
| `lua/quarker/init.lua` | Main module providing `get_marks()`, `get_scope()`, `get_active_scope_name()` — depended on by all three files ⚠️ |
| `lua/quarker/ui/` | UI layer; `ai.lua` calls `require("quarker.ui").show_context()` after generation ⚠️ |
---
## Architecture
```
:Quarker ai generate / refresh / feature
        │
        ▼
   ai.lua (M.generate_context / M.refresh_context / M.generate_feature_note)
        │
        ├── get_marked_files_content()  ──→  quarker.get_marks() + quarker.get_scope()
        ├── get_current_context()       ──→  context.get_content()
        ├── get_git_diff()              ──→  vim.fn.systemlist("git diff ...")
        ├── build_*_prompt()            ──→  string assembly
        │
        └── run_ai_command(backend, prompt, callback)
                │  writes prompt to tmpfile, pipes via shell
                │  `cat tmp | claude --print 2>&1`
                │
                └── on_stdout callback
                        └── context.set_content(result)
                        └── quarker.ui.show_context()
context.lua:
  get_context_path()
    └── sha256(get_scope()) → ~/.local/share/nvim/quarker/<hash>/<scope_name>.context.md
plan.lua:
  discover_plans(root) → glob("plans/*/task_plan.md", "plans/task_plan.md")
  parse_plan(filepath)  → { title, goal, status, phases[{ name, status, items[{checked, text, files}] }] }
```
✅ All data flows above are directly observable in the code.
---
## Sharp Edges
- **Tmpfile race on fast exit**: `os.remove(tmpfile)` is called in `on_stdout` but also in `on_exit` on non-zero code. If stdout fires after a non-zero exit, the file is double-removed — harmless but noisy. ⚠️
- **Shell injection risk**: `get_git_diff(since)` concatenates the `since` argument directly into a shell command string (`"git diff " .. since`). If `since` comes from user input via a command arg, this is a command injection vector. ✅
- **Context keyed by scope hash, not path**: Renaming the project root silently orphans existing context files (the hash changes). ✅
- **`on_stdout` fires with `[""]` on empty output**: `table.concat({"", ""}, "\n")` produces `"\n"`, which after trim becomes `""` — the `if result and result ~= ""` guard correctly handles this. ✅
- **`plan.lua` goto-based parser**: Uses Lua `goto continue` for loop control, which is valid Lua 5.2+ but may confuse static analysis tools. ✅
- **Feature notes write to the project's own `features/` dir** (not `~/.local/share/nvim/quarker/`): `base_scope .. "/features/" .. name`. This means AI output lands inside the actual project directory. ⚠️
- **`search_codebase` hardcodes `rule`, `render`, `template`** as extra patterns alongside the feature name in `build_feature_note_prompt` — these are likely leftover from a prior feature and may produce noisy search results for unrelated features. ✅
---
## Decisions
- **Scope context stored by SHA256 hash of path** rather than the path itself: avoids filesystem-illegal characters in directory names and keeps storage flat. ✅
- **AI runs via shell pipe (`cat tmp | claude --print`)** rather than a Lua RPC or HTTP call: keeps the plugin backend-agnostic and leverages existing CLI tools without needing API keys in Neovim config. ✅
- **`plan.lua` is a pure parser** (no side effects, no `vim.notify`): designed to be called by a UI layer that handles display — clean separation of concerns. ✅
- **Context is per-scope, not per-project**: one project can have multiple named scopes with independent context documents, matching quarker's scope model. ✅
- **`_delete_context` and `_rename_context` are prefixed `_`**: signals they are internal APIs intended only for `quarker/init.lua` lifecycle hooks (scope rename/delete), not for general use. ✅
<!-- quarker-context:end -->
