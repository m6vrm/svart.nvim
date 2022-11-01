local utils = require("svart.utils")
local input = require("svart.input")
local ui = require("svart.ui")
local search = require("svart.search")
local labels = require("svart.labels")
local win = require("svart.win")

local function start_search()
    local matches = {}
    local labeled_matches = {}
    local no_matches = false

    local prompt = ui.prompt()
    local dim = ui.dim()
    local highlight = ui.highlight()

    local marker = labels.make_marker()

    dim.content()

    input.wait_for_input(
        -- get char (return nil = break)
        function (query, label)
            prompt.show(query, label, no_matches)
            ui.redraw()

            local char = vim.fn.getcharstr()

            highlight.clear()

            -- jump to the best match and begin regular search
            if char == input.keys.CR then
                if matches[1] ~= nil then
                    win.jump_to_pos(matches[1])
                    search.regular(query)
                end

                return nil
            end

            if char == input.keys.ESC then
                return nil
            end

            return char
        end,
        -- input handler (return false = break, true = continue)
        function (query, label)
            -- go to the label
            if labeled_matches[label] ~= nil then
                local match = labeled_matches[label]
                win.jump_to_pos(match)
                return false
            end

            matches = search.matches(query)
            no_matches = #matches == 0

            highlight.matches(matches, query)
            highlight.cursor(matches[1])

            labeled_matches = marker.label_matches(matches, query, label)
            highlight.labels(labeled_matches, query)

            return true
        end,
        -- get labels
        function () return utils.table_keys(labeled_matches) end
    )

    dim.clear()
    prompt.clear()
end

return {
    start_search = start_search,
}
