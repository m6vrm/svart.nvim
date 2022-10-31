local buf = require("buf")
local win = require("win")

function get_search_pattern(query)
    return "\\V" .. vim.fn.escape(query, "\\")
end

function directional_search(query, backwards, bounds)
    if query == "" then
        return function () return nil end
    end

    local search_flags = backwards and "b" or ""
    local search_stopline = backwards and bounds.top or bounds.bottom

    local saved_view_state = win.save_view_state()

    return function ()
        local pattern = get_search_pattern(query) .. "\\_."
        local match = vim.fn.searchpos(pattern, search_flags, search_stopline)

        if match[1] == 0 and match[2] == 0 then
            saved_view_state.restore()
            return nil
        end

        return match
    end
end

function regular(query)
    if query == "" then
        return
    end

    local saved_view_state = win.save_view_state()
    local pattern = get_search_pattern(query)

    vim.cmd("/" .. pattern)

    saved_view_state.restore()
end

function matches(query)
    local bounds = buf.get_visible_bounds()
    local matches = {}

    for match in directional_search(query, false, bounds) do
        table.insert(matches, match)
    end

    for match in directional_search(query, true, bounds) do
        table.insert(matches, match)
    end

    return matches
end

return {
    regular = regular,
    matches = matches,
}
