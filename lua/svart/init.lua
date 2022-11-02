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
    local matches = {}
    local labeled_matches = utils.make_bimap()
    local no_matches = false

    local prompt = ui.prompt()
    local dim = ui.dim()
    local highlight = ui.highlight()

    local marker = labels.make_marker()

    dim.content()

    input.wait_for_input(
        -- get char (return nil = break)
        function(query, label)
            prompt.show(query, label, no_matches)
            ui.redraw()

            local char = vim.fn.getcharstr()

            highlight.clear()

            -- jump to the best match and begin regular search
            if char == input.keys.best_match then
                if matches[1] ~= nil then
                    win.jump_to_pos(matches[1])
                    search.begin_regular_search(query)
                end

                return nil
            end

            if char == input.keys.cancel then
                return nil
            end

            return char
        end,
        -- input handler (return false = break, true = continue)
        function(query, label)
            -- go to the label
            if labeled_matches.get_value(label) ~= nil then
                local match = labeled_matches.get_value(label)
                win.jump_to_pos(match)
                return false
            end

            matches = search.get_matches(query)
            no_matches = #matches == 0

            highlight.matches(matches, query)
            highlight.cursor(matches[1])

            labeled_matches = marker.label_matches(matches, query, label)
            highlight.labels(labeled_matches, query)

            return true
        end,
        -- get labels
        function() return labeled_matches.keys() end
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
