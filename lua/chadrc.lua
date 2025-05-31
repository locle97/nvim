-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
    theme = "aquarium",
    transparency = true,

    -- hl_override = {
    -- 	Comment = { italic = true },
    -- 	["@comment"] = { italic = true },
    -- },
}

M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
--}

M.ui = {
    statusline = {
        theme = "default", -- default/vscode/vscode_colored/minimal
        -- default/round/block/arrow separators work only for default statusline theme
        -- round and block will work for minimal theme only
        separator_style = "default",
        order = { "mode", "file", "grapple", "git", "%=", "lsp_msg", "%=", "diagnostics", "rest", "lsp", "cwd", "cursor" },
        modules = {
            grapple = function()
                return " %#Label#" .. require("grapple").statusline()
            end,
            rest = function()
                local current_filetype = vim.bo.filetype
                local absolute_path = vim.b._rest_nvim_env_file
                if current_filetype == "http" and absolute_path ~= nil then
                    local filename = absolute_path:match("^.+/(.+)$")
                    return filename
                end
                return ""
            end,
        },
    }
}

return M
