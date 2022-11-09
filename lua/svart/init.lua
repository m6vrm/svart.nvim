local buf = require("svart.buf")
local config = require("svart.config")
local input = require("svart.input")
local labels = require("svart.labels")
local search = require("svart.search")
local ui = require("svart.ui")
local utils = require("svart.utils")
local win = require("svart.win")

local function make_params(exact, query, labels_ctx)
    return {
        exact = exact ~= false,
        query = query or "",
        labels_ctx = labels_ctx or nil,
    }
end

local prev_params = make_params()

local function accept_match(match, params)
    assert(params.exact ~= nil)
    assert(params.query ~= nil)
    assert(params.labels_ctx ~= nil)

    prev_params = params
    win.jump_to(match)

    if config.search_update_register then
        search.update_register(params.exact, params.query)
    end
end

local function excluded_win_ids()
    -- in OP- and V-mode
    -- exclude windows with other than current buffer
    if win.is_op_mode() or win.is_visual_mode() then
        local win_ids = win.other_buf_win_ids()
        return utils.table_flip(win_ids)
    end

    return {}
end

local M = {}

function M.configure(overrides)
    for key, value in pairs(overrides) do
        config[key] = value
    end
end

function M.search(params)
    local params = params or make_params()
    local exact = params.exact
    local query = params.query

    local excluded_win_ids = excluded_win_ids()

    local win_ctx = win.make_context()
    local search_ctx = search.make_context(config, win, excluded_win_ids)
    local labels_ctx = params.labels_ctx or labels.make_context(config, buf, win, excluded_win_ids)

    local prompt = ui.prompt()
    local dim = ui.dim(win_ctx)
    local highlight = ui.highlight(config)

    if config.ui_dim_content then
        dim.content()
    end

    input.wait_for_input(
        query,
        -- get labels
        function() return labels_ctx.labels() end,
        -- get char (return nil = break loop)
        function(query, label)
            prompt.show(query, label, search_ctx.is_empty())
            ui.redraw()

            local char = vim.fn.getcharstr()

            highlight.clear()

            if char == input.keys.best_match then
                -- accept current match and jump to it
                if search_ctx.best_match() ~= nil then
                    local match = search_ctx.best_match()
                    local params = make_params(exact, query, labels_ctx)
                    accept_match(match, params)
                end

                return nil
            elseif char == input.keys.cancel then
                return nil
            elseif char == input.keys.next_match then
                -- move cursor to the next match
                search_ctx.next_match()
            elseif char == input.keys.prev_match then
                -- move cursor to the previous match
                search_ctx.prev_match()
            end

            return char
        end,
        -- input handler (return false = break loop)
        function(query, label)
            -- jump to the label
            if labels_ctx.has_label(label) then
                local match = labels_ctx.match(label)
                local params = make_params(exact, query, labels_ctx)
                accept_match(match, params)
                return false
            end

            local matches = search.search(exact, query, win_ctx)

            search_ctx.reset(matches)
            labels_ctx.label_matches(matches, query, label)

            highlight.matches(matches)
            highlight.cursor(search_ctx.best_match())
            highlight.labels(labels_ctx.labeled_matches())

            return true
        end
    )

    dim.clear()
    prompt.clear()
end

function M.search_regex()
    M.search(make_params(false))
end

function M.do_repeat()
    M.search(prev_params)
end

return M
