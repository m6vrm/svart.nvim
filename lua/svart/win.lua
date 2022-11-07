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

local function push_cursor(backwards)
    local flags = backwards and "Wb" or "W"
    vim.fn.search("\\_.", flags)
end

-- current window is guaranteed to be first
local function focusable_win_ids()
    local current_win_id = vim.api.nvim_get_current_win()
    local win_ids = { current_win_id }

    -- use focusable windows from the current tab
    local tab_win_ids = vim.api.nvim_tabpage_list_wins(0)

    for _, win_id in ipairs(tab_win_ids) do
        local focusable = vim.api.nvim_win_get_config(win_id).focusable

        if win_id ~= current_win_id and focusable then
            table.insert(win_ids, win_id)
        end
    end

    return win_ids
end

local M = {}

function M.is_op_mode()
    local mode = vim.api.nvim_get_mode().mode
    return mode:match("o")
end

function M.is_visual_mode()
    local mode = vim.api.nvim_get_mode().mode
    return mode:lower():match("v")
end

function M.save_view_state()
    local view = vim.fn.winsaveview()

    local this = {}

    this.restore = function()
        vim.fn.winrestview(view)
    end

    return this
end

function M.make_context()
    local win_ids = focusable_win_ids()

    local this = {}

    this.for_each = function(win_handler)
        assert(next(win_ids) ~= nil)

        local saved_win_id = vim.api.nvim_get_current_win()

        for _, win_id in ipairs(win_ids) do
            vim.api.nvim_set_current_win(win_id)
            win_handler(win_id, saved_win_id)
        end

        vim.api.nvim_set_current_win(saved_win_id)
    end

    return this
end

function M.run_on(win_id, win_handler)
    local saved_win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(win_id)

    local result = win_handler()

    vim.api.nvim_set_current_win(saved_win_id)
    return result
end

function M.current_buf_win_ids()
    local win_ids = {}
    local focusable_win_ids = focusable_win_ids()
    local current_buf_id = vim.api.nvim_get_current_buf()

    for _, win_id in ipairs(focusable_win_ids) do
        local buf_id = vim.fn.winbufnr(win_id)

        if buf_id == current_buf_id then
            table.insert(win_ids, win_id)
        end
    end

    return win_ids
end

function M.cursor()
    local win_id = vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_cursor(0)
    local line, col = unpack(pos)
    return { win_id = win_id, line = line, col = col + 1 }
end

function M.jump_to(pos)
    vim.api.nvim_set_current_win(pos.win_id)

    local cursor = M.cursor()
    local direction = direction(cursor, pos)

    vim.api.nvim_win_set_cursor(pos.win_id, { pos.line, pos.col - 1 })

    M.run_on(pos.win_id, function()
        -- todo: OP-mode on EOF doesn't work properly
        if M.is_op_mode() and direction ~= -1 then
            push_cursor()
        end
    end)
end

return M
