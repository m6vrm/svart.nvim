local buf = require("svart.buf")
local win = require("svart.win")

local function get_search_regex(query)
    return "\\V" .. vim.fn.escape(query, "\\")
end

local function directional_search(query, backwards, bounds)
    if query == "" then
        return function () return nil end
    end

    local search_flags = backwards and "b" or ""
    local search_stopline = backwards and bounds.top or bounds.bottom

    local saved_view_state = win.save_view_state()

    return function ()
        local regex = get_search_regex(query) .. "\\_."
        local match = vim.fn.searchpos(regex, search_flags, search_stopline)

        if match[1] == 0 and match[2] == 0 then
            saved_view_state.restore()
            return nil
        end

        return match
    end
end

local function begin_regular_search(query)
    if query == "" then
        return
    end

    local saved_view_state = win.save_view_state()
    local regex = get_search_regex(query)

    vim.cmd("/" .. regex)

    saved_view_state.restore()
end

local function get_matches(query)
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
    begin_regular_search = begin_regular_search,
    get_matches = get_matches,
}
