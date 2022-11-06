local config = require("svart.config")
local utils = require("svart.utils")
local input = require("svart.input")
local ui = require("svart.ui")
local search = require("svart.search")
local labels = require("svart.labels")
local win = require("svart.win")

local prev_query = ""
local prev_labels_ctx = nil

local function accept_match(match, query, labels_ctx)
    assert(query ~= nil)
    assert(labels_ctx ~= nil)

    win.jump_to(match)

    if config.search_begin_regular then
        search.regular_search(query)
    end

    prev_query = query
    prev_labels_ctx = labels_ctx
end

local function setup(overrides)
    for key, value in pairs(overrides) do
        config[key] = value
    end
end

local function start(query, labels_ctx)
    local query = query or ""

    local search_ctx = search.make_context(win.cursor(), config.search_wrap_around)
    local labels_ctx = labels_ctx or labels.make_context()

    local prompt = ui.prompt()
    local dim = ui.dim()
    local highlight = ui.highlight()

    dim.content()

    input.wait_for_input(
        query,
        -- get labels
        function() return labels_ctx.labels() end,
        -- get char (return nil = break)
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
        -- input handler (return false = break)
        function(query, label)
            -- jump to the label
            if labels_ctx.has_label(label) then
                local match = labels_ctx.match(label)
                accept_match(match, query, labels_ctx)
                return false
            end

            local matches = search.search(query)

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

function do_repeat()
    start(prev_query, prev_labels_ctx)
end

return {
    setup = setup,
    start = start,
    do_repeat = do_repeat,
}
