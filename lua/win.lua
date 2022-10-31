function save_view_state()
    local view = vim.fn.winsaveview()

    return {
        restore = function ()
            vim.fn.winrestview(view)
        end,
    }
end

function jump_to_pos(pos)
    vim.api.nvim_win_set_cursor(0, { pos[1], pos[2] - 1 })
end

function get_cursor_pos()
    local pos = vim.api.nvim_win_get_cursor(0)
    return { pos[1], pos[2] + 1 }
end

return {
    save_view_state = save_view_state,
    jump_to_pos = jump_to_pos,
    get_cursor_pos = get_cursor_pos,
}
