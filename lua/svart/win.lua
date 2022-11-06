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

-- 1 = forward, -1 = backward, 0 = none
-- todo: write tests
local function direction(from, to)
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

local function cursor()
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = unpack(pos)
    return { line, col + 1 }
end

local function jump_to(pos)
    local direction = direction(cursor(), pos)
    local line, col = unpack(pos)
    vim.api.nvim_win_set_cursor(0, { line, col - 1 })

    -- todo: OP-mode on EOF doesn't work properly
    if is_op_mode() and direction ~= -1 then
        push_cursor()
    end
end

local function run_on(win_id, win_handler)
    local saved_win_id = vim.fn.win_getid()
    vim.api.nvim_set_current_win(win_id)

    local result = win_handler()

    vim.api.nvim_set_current_win(saved_win_id)
    return result
end

local function make_context()
    local wins = { vim.fn.win_getid() }

    return {
        for_each = function(win_handler)
            local saved_win_id = vim.fn.win_getid()

            for _, win_id in ipairs(wins) do
                vim.api.nvim_set_current_win(win_id)
                win_handler(win_id)
            end

            vim.api.nvim_set_current_win(saved_win_id)
        end,
    }
end

return {
    save_view_state = save_view_state,
    jump_to = jump_to,
    cursor = cursor,
}
