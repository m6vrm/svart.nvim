local input = require("input")
local ui = require("ui")
local search = require("search")
local labels = require("labels")
local win = require("win")

function start_search()
    local matches = {}
    local labeled_matches = {}
    local prompt_error = false

    local prompt = ui.prompt()
    local dim = ui.dim()
    local highlight = ui.highlight()

    dim.content()

    input.wait_for_input(
        -- get char
        function (query)
            prompt.show(query, prompt_error)
            ui.redraw()

            local char = vim.fn.getcharstr()

            highlight.clear()

            if char == input.keys.ESC then
                return nil
            end

            if char == input.keys.CR then
                if matches[1] ~= nil then
                    win.jump_to_pos(matches[1])
                    search.regular(query)
                end

                return nil
            end

            if labeled_matches[char] ~= nil then
                local match = labeled_matches[char]
                win.jump_to_pos(match)
                return nil
            end

            return char
        end,
        -- input handler
        function (query)
            labeled_matches = {}
            prompt_error = false

            matches = search.matches(query)

            if #matches == 0 then
                prompt_error = true
            else
                highlight.matches(matches, query)

                labeled_matches = labels.label_matches(matches, query)
                highlight.labels(labeled_matches, query)

                highlight.cursor(matches[1])
            end
        end
    )

    dim.clear()
    prompt.clear()
end

return {
    start_search = start_search,
}
