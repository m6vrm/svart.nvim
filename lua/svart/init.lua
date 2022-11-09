local buf = require("svart.buf")
local config = require("svart.config")
local input = require("svart.input")
local labels = require("svart.labels")
local search = require("svart.search")
local ui = require("svart.ui")
local utils = require("svart.utils")
local win = require("svart.win")

local prev_query = ""
local prev_labels_ctx = nil

local function accept_match(match, query, labels_ctx)
    assert(query ~= nil)
    assert(labels_ctx ~= nil)

    win.jump_to(match)

    if config.search_update_register then
        search.update_register(query)
    end

    prev_query = query
    prev_labels_ctx = labels_ctx
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

function M.search(query, labels_ctx)
    local query = query or ""
    local excluded_win_ids = excluded_win_ids()

    local win_ctx = win.make_context()
    local search_ctx = search.make_context(config, win, excluded_win_ids)
    local labels_ctx = labels_ctx or labels.make_context(config, buf, win, excluded_win_ids)

    local prompt = ui.prompt()
    local dim = ui.dim(win_ctx)
    local highlight = ui.highlight()

    dim.content()

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
                    accept_match(match, query, labels_ctx)
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
                accept_match(match, query, labels_ctx)
                return false
            end

            local matches = search.search(query, win_ctx, win, buf)

            search_ctx.reset(matches)
            labels_ctx.label_matches(matches, query, label)

            highlight.matches(matches, query)
            highlight.cursor(search_ctx.best_match())
            highlight.labels(labels_ctx.labeled_matches(), query)

            return true
        end
    )

    dim.clear()
    prompt.clear()
end

function M.do_repeat()
    M.search(prev_query, prev_labels_ctx)
end

return M
