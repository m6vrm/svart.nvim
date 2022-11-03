local function save_view_state()
    local view = vim.fn.winsaveview()

    return {
        restore = function()
            vim.fn.winrestview(view)
        end,
    }
end

local function jump_to_pos(pos)
    local line, col = unpack(pos)
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })
end

local function cursor_pos()
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = unpack(pos)
    return { line, col + 1 }
end

return {
    save_view_state = save_view_state,
    jump_to_pos = jump_to_pos,
    cursor_pos = cursor_pos,
}
