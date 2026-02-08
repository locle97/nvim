# Task Plan: quack-review - Agent Diff Review Mode for Neovim

## Goal
Build `quack-review`, a Neovim plugin that provides an interactive, hunk-by-hunk code review experience for agent-generated diffs, with accept/reject/comment workflow and structured feedback export.

## Current Phase
COMPLETE

## Phases

### Phase 1: Core Infrastructure & Diff Parser
- [x] Create `lua/quack-review/init.lua` - main module with setup, state machine, public API
- [x] Create `lua/quack-review/parser.lua` - git diff parser (files, hunks, line ranges)
- [x] Create `lua/quack-review/state.lua` - review session state management (hunk statuses, feedback)
- [x] Create `lua/plugins/quack-review.lua` - lazy.nvim plugin spec
- [x] Write tests / manual validation for diff parsing
- **Status:** complete

### Phase 2: UI - Summary & Diff Buffers
- [x] Create `lua/quack-review/ui/summary.lua` - top summary panel (files changed, hunks, +/-)
- [x] Create `lua/quack-review/ui/diff.lua` - diff hunk display buffer (read-only, syntax highlighted)
- [x] Create `lua/quack-review/ui/actions.lua` - right panel showing hunk status & actions
- [x] Create `lua/quack-review/ui/layout.lua` - window layout manager (splits, floating, resize)
- [x] Create `lua/quack-review/ui/init.lua` - UI orchestrator (open/close/refresh + keymaps)
- [x] Implement sign column indicators (+/- signs in diff view)
- [x] Implement reactive UI refresh on state changes
- **Status:** complete

### Phase 3: Navigation & Keybindings
- [ ] Implement hunk-by-hunk navigation (`n`/`p` next/prev hunk globally)
- [ ] Implement file-level navigation (`]f`/`[f` next/prev file)
- [ ] Implement unresolved hunk jump (`]u`/`[u`)
- [ ] Implement action keys (`a` accept, `r` reject, `c` comment, `q` quit)
- [ ] Implement batch actions (`A` apply accepted, `R` revert rejected)
- [ ] Winbar with context: `file.ts  |  Hunk 2/3  |  pending`
- **Status:** pending

### Phase 4: Comment/Feedback System
- [x] Implement floating multi-line comment input (`c` key → float with `<C-s>` save, `<Esc>` cancel)
- [x] Store feedback bound to specific hunks (state.comment + state.get_feedback)
- [x] Export structured JSON payload (accepted, rejected, comments with diff context)
- [x] Export human-readable markdown summary with rejected hunks + feedback sections
- [x] `S` key exports JSON + markdown + clipboard
- **Status:** complete

### Phase 5: Git Integration & Apply/Revert
- [x] Implement "apply accepted hunks" — keep accepted, revert rejected via reverse patch
- [x] Implement per-hunk revert using `git apply --reverse --unidiff-zero` (patch-based)
- [x] Implement `A` key (apply with preview/confirm) and `R` key (revert menu)
- [x] Support custom diff sources (unstaged, staged, head, HEAD~N, arbitrary refs)
- [x] Validated patch format with `git apply --check --reverse` (exit code 0)
- [x] Preview command shows what will happen before applying
- **Status:** complete

### Phase 6: Plugin Spec & Polish
- [x] Upgrade `lua/plugins/quack-review.lua` — lazy-load on `cmd` + `keys` triggers
- [x] Add `<leader>qr` (unstaged) and `<leader>qR` (all uncommitted) keybindings
- [x] Add statusline integration — `quack_review` module in chadrc (shows during active reviews)
- [x] Clean entry/exit — `keepjumps tabnew`, autocmd cleanup, TabClosed stops session
- [x] Prevent accidental splits inside review tab (WinNew guard)
- [x] Added mappings to `lua/mappings.lua` git section
- [x] Written MEMORY.md with plugin architecture reference
- **Status:** complete

## Key Questions
1. Should the diff source default to `git diff` (unstaged) or `git diff HEAD` (all uncommitted)?
2. How to handle per-hunk revert? Patch-based or line-range checkout?
3. Should comments be persisted to disk (like quarker marks) or session-only?
4. What's the feedback export format for agent integration? JSON file? Clipboard? Pipe?
5. Should this integrate with quarker scopes for context-aware reviews?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Standalone plugin (not inside quarker) | Separation of concerns; quack-review is review-focused, quarker is marks-focused |
| Git diff as source of truth | Reliable, no dependency on gitsigns internals, parseable |
| Custom buffers (buftype=nofile) for all panels | Prevents accidental edits, jumplist pollution |
| Follow quarker patterns (float windows, state management, keymaps) | Consistency with existing nvim config style |
| Hunk-centric navigation (not file-centric) | PR-review UX paradigm - user reviews linearly, not randomly |
| Single-letter keybindings in review mode | Fast, no leader prefix needed in a modal review context |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
|       | 1       |            |

## Notes
- Follow the quarker pattern: `lua/quack-review/` directory with init.lua, submodules, and `lua/quack-review/ui/` for UI components
- Reuse `quarker/ui/float.lua` patterns for floating window creation
- Plugin name: `quack-review` (kebab-case dirs, user command `:QuackReview`)
- Start with MVP: parse diff, navigate hunks, accept/reject state, summary buffer
