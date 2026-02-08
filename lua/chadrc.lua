-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
    theme = "aquarium",
    transparency = true,

    hl_override = {
        TelescopeSelection = { bg = "#34343e", fg = "#ced4df", bold = true },
    },
}

M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
--}

M.ui = {
    tabufline = {
         lazyload = false
    },
    statusline = {
        theme = "minimal", -- default/vscode/vscode_colored/minimal
        -- default/round/block/arrow separators work only for default statusline theme
        -- round and block will work for minimal theme only
        separator_style = "default",
        order = { "mode", "file", "quarker", "quack_review", "%=", "lsp_msg", "%=", "diagnostics", "lsp", "cwd", "cursor" },
        modules = {
            quarker = function()
                return "%#Label#" .. require("quarker").statusline()
            end,
            quack_review = function()
                local ok, qr = pcall(require, "quack-review")
                if ok then
                    return "%#DiagnosticInfo#" .. qr.statusline()
                end
                return ""
            end,
        },
    },
}

return M
