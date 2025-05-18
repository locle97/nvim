require "nvchad.options"

local o = vim.o
local g = vim.g
local opt = vim.opt
g.mapleader = " "

-- local o = vim.o
o.cursorlineopt = 'both' -- to enable cursorline!

-- Indenting
o.expandtab = true
o.shiftwidth = 4
o.smartindent = true
o.tabstop = 4
o.wrap = false

opt.relativenumber = true

vim.filetype.add({
    -- Detect and assign filetype based on the extension of the filename
    extension = {
        cql = "cypher",
        cypher = "cypher",
        resx = "xml",
    },
})

vim.cmd('highlight St_Lsp guifg=#94e2d5')
