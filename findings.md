# Findings & Decisions - quack-review

## Requirements
- Interactive hunk-by-hunk code review inside Neovim
- Accept/Reject/Comment workflow per hunk
- Visual indicators (signs, virtual text) for hunk status
- Summary panel showing scope (files changed, hunks, +/-)
- Navigation: by hunk (n/p), by file (]f/[f), by unresolved (]u/[u)
- Feedback export as structured JSON for agent consumption
- Apply accepted / revert rejected hunks
- Plugin name: `quack-review`

## Research Findings

### Existing Codebase Patterns (from quarker)
- **Plugin structure**: `lua/{plugin}/init.lua` as main module, submodules for features
- **UI pattern**: `lua/{plugin}/ui/float.lua` provides reusable floating window primitives
  - `get_window_config(width_ratio, height_ratio, title, footer)` - centered floats
  - `create_float_win(opts)` - buffer creation + window management
  - `render_lines(bufnr, lines, highlights)` - text rendering with highlights
  - `set_float_keymaps(bufnr, mappings)` - buffer-local keymap helper
- **State management**: Module-level tables + caching with `vim.loop.hrtime()`
- **Data persistence**: JSON files in `vim.fn.stdpath("data")/{plugin}/`
- **Git root detection**: `git rev-parse --show-toplevel` with caching
- **Commands**: `nvim_create_user_command` with subcommand dispatch + tab completion
- **Lazy loading**: Plugin specs in `lua/plugins/{name}.lua`, loaded via events/commands

### Git Diff Parsing Strategy
- `git diff --unified=3` gives standard unified diff output
- Parse structure: file headers (`diff --git`), hunk headers (`@@`), context/add/remove lines
- Each hunk has: file path, old line range, new line range, diff content
- Line counts from `@@ -start,count +start,count @@`

### Existing Git Setup
- **gitsigns.nvim**: Already configured, provides sign column + hunk navigation (`]c`/`[c`)
- **lazygit.nvim**: TUI git client via `<leader>gl`
- No diffview or fugitive installed
- quack-review does NOT conflict with these - it's a separate review mode

### UI Layout Design
- 3-panel layout: Summary (top), Diff (bottom-left), Actions (bottom-right)
- Summary: read-only buffer listing files + hunk counts
- Diff: read-only buffer with `syntax=diff` for highlighting
- Actions: read-only buffer showing current hunk state + available actions
- All buffers: `buftype=nofile`, `modifiable=false`, `swapfile=false`

### Hunk State Model
```lua
hunk = {
  file = "relative/path.lua",
  index = 1,           -- hunk index within file
  global_index = 1,    -- hunk index across all files
  total_in_file = 3,   -- total hunks in this file
  status = "pending",  -- pending | accepted | rejected | commented
  header = "@@ -21,7 +21,15 @@",
  old_start = 21, old_count = 7,
  new_start = 21, new_count = 15,
  lines = { ... },     -- diff lines (context + added + removed)
  feedback = nil,      -- string feedback if commented
}
```

### Visual Language
| Status    | Sign | Color  | Icon |
|-----------|------|--------|------|
| Pending   | `?`  | Yellow | `?`  |
| Accepted  | `+`  | Green  | `✔` |
| Rejected  | `x`  | Red    | `✘` |
| Commented | `c`  | Blue   | `💬` |

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Parse `git diff` output directly | More reliable than gitsigns API; gives exact hunk structure |
| Module-level state (no OOP) | Consistent with quarker patterns; simpler in Lua |
| JSON export for feedback | Machine-readable, agent-friendly, grep-able |
| Reuse float.lua patterns | DRY, consistent look-and-feel with quarker |
| Split layout (not floating) | Review needs persistent reference panels, not ephemeral popups |
| Floating window for comment input | Quick input, doesn't disturb layout |
| Custom namespace for highlights | Isolated from other plugin highlights |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
|       |            |

## Resources
- Quarker init.lua: `lua/quarker/init.lua` (1077 lines) - reference for plugin structure
- Quarker float.lua: `lua/quarker/ui/float.lua` (171 lines) - reference for floating windows
- Git plugin spec: `lua/plugins/git.lua` - reference for lazy.nvim plugin spec
- Mappings: `lua/mappings.lua` (194 lines) - reference for keybinding patterns
- NvChad gitsigns config: `lua/nvchad/configs/gitsigns.lua` - existing git signs setup

## Module Structure Plan
```
lua/quack-review/
├── init.lua          -- Public API, setup, user command
├── parser.lua        -- Git diff parsing → structured hunks
├── state.lua         -- Review session state management
├── export.lua        -- Feedback JSON export
└── ui/
    ├── init.lua      -- UI orchestrator (open/close layout)
    ├── layout.lua    -- Window layout management
    ├── summary.lua   -- Summary panel renderer
    ├── diff.lua      -- Diff hunk renderer
    └── actions.lua   -- Actions panel renderer

lua/plugins/
└── quack-review.lua  -- Lazy.nvim plugin spec
```
