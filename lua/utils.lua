M = {}

M.remove_other_buffers = function()
    local current_buf = vim.api.nvim_get_current_buf()
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
        if buf ~= current_buf and vim.api.nvim_buf_is_loaded(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

return M
