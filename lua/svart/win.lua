local utils = require("svart.utils")

-- 1 = forward, -1 = backward, 0 = none
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

local function win_is_searchable(win_id)
    if not vim.api.nvim_win_is_valid(win_id) then
        return false
    end

    local config = vim.api.nvim_win_get_config(win_id)
    return config.focusable
end

-- current window is guaranteed to be first
local function searchable_win_ids(only_current)
    local current_win_id = vim.api.nvim_get_current_win()
    local win_ids = win_is_searchable(current_win_id)
        and { current_win_id }
        or {}

    if not only_current then
        -- append searchable windows from the current tab
        local tab_win_ids = vim.api.nvim_tabpage_list_wins(0)

        for _, win_id in ipairs(tab_win_ids) do
            if win_id ~= current_win_id and win_is_searchable(win_id) then
                table.insert(win_ids, win_id)
            end
        end
    end

    return win_ids
end

-- windows with buffers other than current
local function other_buf_win_ids()
    local current_buf_id = vim.api.nvim_get_current_buf()
    local searchable_win_ids = searchable_win_ids(false)
    local win_ids = {}

    for _, win_id in ipairs(searchable_win_ids) do
        local buf_id = vim.fn.winbufnr(win_id)

        if buf_id ~= current_buf_id then
            table.insert(win_ids, win_id)
        end
    end

    return win_ids
end

local function is_op_mode()
    local mode = vim.api.nvim_get_mode().mode
    return mode:lower():match("o")
end

local function is_visual_mode()
    local mode = vim.api.nvim_get_mode().mode
    return mode:lower():match("v")
end

local M = {}

function M.save_view_state()
    local view = vim.fn.winsaveview()

    local this = {}

    this.restore = function()
        vim.fn.winrestview(view)
    end

    return this
end

function M.make_context(config)
    local current_win_id = vim.api.nvim_get_current_win()

    local this = {}

    this.for_each = function(win_handler)
        -- always get actual searchable win ids
        local win_ids = searchable_win_ids(not config.search_multi_window)
        assert(next(win_ids) ~= nil)

        for _, win_id in ipairs(win_ids) do
            vim.api.nvim_set_current_win(win_id)
            win_handler(win_id)
        end

        if vim.api.nvim_win_is_valid(current_win_id) then
            vim.api.nvim_set_current_win(current_win_id)
        end
    end

    -- in OP- and V-modes exclude windows
    -- with other than current buffer
    this.excluded_win_ids = function()
        if is_op_mode() or is_visual_mode() then
            local win_ids = other_buf_win_ids()
            return utils.table_flip(win_ids)
        end

        return {}
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
        if is_op_mode() and direction ~= -1 then
            push_cursor(false)
        end
    end)
end

function M.buf_nr(win_id, callback)
    local buf_nr = vim.fn.winbufnr(win_id)
    if buf_nr ~= -1 then callback(buf_nr) end
end

function M.test(tests)
    -- direction
    do
        -- forward
        local dir = direction({ line = 1, col = 1 }, { line = 1, col = 2 })
        tests.assert_eq(dir, 1)

        dir = direction({ line = 1, col = 1 }, { line = 2, col = 1 })
        tests.assert_eq(dir, 1)

        -- backwards
        dir = direction({ line = 1, col = 2 }, { line = 1, col = 1 })
        tests.assert_eq(dir, -1)

        dir = direction({ line = 2, col = 1 }, { line = 1, col = 1 })
        tests.assert_eq(dir, -1)

        -- no direction
        dir = direction({ line = 1, col = 1 }, { line = 1, col = 1 })
        tests.assert_eq(dir, 0)
    end
end

return M
