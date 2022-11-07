local function is_op_mode()
    local mode = vim.api.nvim_get_mode().mode
    return mode:match("o")
end

local function push_cursor(backwards)
    local flags = backwards and "Wb" or "W"
    vim.fn.search("\\_.", flags)
end

-- 1 = forward, -1 = backward, 0 = none
-- todo: write tests
local function direction(from, to)
    if to.line > from.line then
        return 1
    elseif to.line < from.line then
        return -1
    elseif to.col > from.col then
        return 1
    elseif to.col < from.col then
        return -1
    else
        return 0
    end
end

local function save_view_state()
    local view = vim.fn.winsaveview()

    return {
        restore = function()
            vim.fn.winrestview(view)
        end,
    }
end

local function make_context()
    local current_win_id = vim.fn.win_getid()
    local win_ids = { current_win_id }

    -- use focusable windows from the current tab
    local tab_win_ids = vim.api.nvim_tabpage_list_wins(0)

    for _, win_id in ipairs(tab_win_ids) do
        local focusable = vim.api.nvim_win_get_config(win_id).focusable

        if win_id ~= current_win_id and focusable then
            table.insert(win_ids, win_id)
        end
    end

    return {
        -- current window guaranteed to be first
        for_each = function(win_handler)
            assert(next(win_ids) ~= nil)

            local saved_win_id = vim.fn.win_getid()

            for _, win_id in ipairs(win_ids) do
                vim.api.nvim_set_current_win(win_id)
                win_handler(win_id, saved_win_id)
            end

            vim.api.nvim_set_current_win(saved_win_id)
        end,
    }
end

local function run_on(win_id, win_handler)
    local saved_win_id = vim.fn.win_getid()
    vim.api.nvim_set_current_win(win_id)

    local result = win_handler()

    vim.api.nvim_set_current_win(saved_win_id)
    return result
end

local function cursor()
    local win_id = vim.fn.win_getid()
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = unpack(pos)
    return { win_id = win_id, line = line, col = col + 1 }
end

local function jump_to(pos)
    vim.api.nvim_set_current_win(pos.win_id)

    local cursor = cursor()
    local direction = direction(cursor, pos)

    vim.api.nvim_win_set_cursor(pos.win_id, { pos.line, pos.col - 1 })

    run_on(pos.win_id, function()
        -- todo: OP-mode on EOF doesn't work properly
        if is_op_mode() and direction ~= -1 then
            push_cursor()
        end
    end)
end

return {
    save_view_state = save_view_state,
    make_context = make_context,
    run_on = run_on,
    jump_to = jump_to,
    cursor = cursor,
}
