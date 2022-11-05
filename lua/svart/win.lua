local function is_op_mode()
    local mode = vim.api.nvim_get_mode().mode
    return mode:match("o")
end

local function push_cursor(backwards)
    local flags = backwards and "Wb" or "W"
    vim.fn.search("\\_.", flags)
end

local function save_view_state()
    local view = vim.fn.winsaveview()

    return {
        restore = function()
            vim.fn.winrestview(view)
        end,
    }
end

local function direction(from, to) -- 1 = forward, -1 = backwards, 0 = none
    if to[1] > from[1] then
        return 1
    elseif to[1] < from[1] then
        return -1
    elseif to[2] > from[2] then
        return 1
    elseif to[2] < from[2] then
        return -1
    else
        return 0
    end
end

local function cursor_pos()
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = unpack(pos)
    return { line, col + 1 }
end

local function jump_to_pos(pos)
    local direction = direction(cursor_pos(), pos)
    local line, col = unpack(pos)
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })

    if is_op_mode() and direction ~= -1 then
        push_cursor()
    end
end

return {
    save_view_state = save_view_state,
    jump_to_pos = jump_to_pos,
    cursor_pos = cursor_pos,
}
