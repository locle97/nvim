# Neovim Configuration - Agent Guidelines

## Build/Lint/Test Commands
- **Format Lua files**: `stylua .` (uses .stylua.toml config)
- **Format single file**: `stylua <file.lua>`
- **No automated tests** - this is a Neovim configuration
- **Check syntax**: Open file in Neovim and use LSP diagnostics

## Code Style Guidelines
- **Language**: Lua only
- **Indentation**: 2 spaces (per .stylua.toml), but existing files use 4 spaces - follow existing pattern
- **Line length**: 120 characters max
- **Quotes**: Auto-prefer double quotes
- **Function calls**: No parentheses when possible (`call_parentheses = "None"`)

## File Structure
- `lua/configs/` - Plugin configurations
- `lua/plugins/` - Plugin definitions
- `lua/nvchad/` - NvChad framework overrides
- `lua/commands/` - Custom commands
- `lua/snippets/` - Code snippets

## Naming Conventions
- Use snake_case for file names
- Use descriptive names for plugin files (e.g., `nvim-lspconfig.lua`, `toggle-term.lua`)
- Follow existing patterns in similar files

## Error Handling
- Use `pcall()` for potentially failing operations
- Provide fallbacks for missing dependencies
- Use descriptive error messages with context