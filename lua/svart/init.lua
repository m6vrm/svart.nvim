local config = require("svart.config")
local utils = require("svart.utils")
local input = require("svart.input")
local ui = require("svart.ui")
local search = require("svart.search")
local labels = require("svart.labels")
local win = require("svart.win")

local function setup(overrides)
    for key, value in pairs(overrides) do
        config[key] = value
    end
end

local function start()
    local search_ctx = search.make_context(win.cursor_pos())
    local labels_ctx = labels.make_context()

    local prompt = ui.prompt()
    local dim = ui.dim()
    local highlight = ui.highlight()

    dim.content()

    input.wait_for_input(
        -- get char (return nil = break)
        function(query, label)
            prompt.show(query, label, search_ctx.is_empty())
            ui.redraw()

            local char = vim.fn.getcharstr()

            highlight.clear()

            if char == input.keys.best_match then
                if search_ctx.current_match() then
                    win.jump_to_pos(search_ctx.current_match())
                    search.regular_search(query)
                end

                return nil
            elseif char == input.keys.cancel then
                return nil
            elseif char == input.keys.next_match then
                search_ctx.next_match()
            elseif char == input.keys.prev_match then
                search_ctx.prev_match()
            end

            return char
        end,
        -- input handler (return false = break)
        function(query, label)
            if labels_ctx.has_label(label) then
                local match = labels_ctx.match(label)
                win.jump_to_pos(match)
                return false
            end

            local matches = search.search(query)
            search_ctx.reset(matches)

            highlight.matches(matches, query)
            highlight.cursor(search_ctx.current_match())

            labels_ctx.label_matches(matches, query)
            labels_ctx.discard_irrelevant_labels(label)

            highlight.labels(labels_ctx.labeled_matches(), query)

            return true
        end,
        -- get labels
        function() return labels_ctx.labels() end
    )

    dim.clear()
    prompt.clear()
end

function do_repeat()
end

return {
    setup = setup,
    start = start,
    do_repeat = do_repeat,
}
