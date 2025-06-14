dofile(vim.g.base46_cache .. "telescope")

return {
    defaults = {
        prompt_prefix = "   ",
        selection_caret = " ",
        entry_prefix = " ",
        sorting_strategy = "ascending",
        layout_config = {
            horizontal = {
                prompt_position = "top",
                preview_width = 0.40,
            },
            width = { padding = 0 },
            height = { padding = 0 },
        },
        mappings = {
            n = { ["q"] = require("telescope.actions").close },
        },
        path_display = {
            "filename_first"
        },
    },
    pickers = {
        lsp_references = {
            path_display = {
                "filename_first"
            }
        }
    },
    extensions_list = { "themes", "terms", "grapple", "rest", "live_grep_args" },
    extensions = {
        live_grep_args = {
            auto_quoting = false
        }
    },
}
