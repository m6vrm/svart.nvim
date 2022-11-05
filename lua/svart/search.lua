local utils = require("svart.utils")
local buf = require("svart.buf")
local win = require("svart.win")

local function search_regex(query)
    return "\\V" .. vim.fn.escape(query, "\\")
end

local function directional_search(query, backwards, bounds)
    if query == "" then
        return function() return nil end
    end

    local search_flags = backwards and "b" or ""
    local search_stopline = backwards and bounds.top or bounds.bottom

    local saved_view_state = win.save_view_state()
    local first_search = true

    return function()
        local cursor_match_flag = first_search and not backwards and "c" or ""
        first_search = false

        local regex = search_regex(query) .. "\\_."
        local match = vim.fn.searchpos(regex, search_flags .. cursor_match_flag, search_stopline)
        local line, col = unpack(match)

        if line == 0 and col == 0 then
            saved_view_state.restore()
            return nil
        end

        return match
    end
end

local function regular_search(query)
    if query == "" then
        return
    end

    local saved_view_state = win.save_view_state()
    local regex = search_regex(query)

    vim.cmd("/" .. regex)

    saved_view_state.restore()
end

local function search(query)
    local bounds = buf.visible_bounds()
    local matches = {}

    for match in directional_search(query, false, bounds) do
        table.insert(matches, match)
    end

    for match in directional_search(query, true, bounds) do
        table.insert(matches, match)
    end

    return matches
end

local function make_context(cursor_pos)
    local matches = {}
    local current_index = 0
    local current_match = nil

    local set_current_index = function(index)
        current_index = index
        current_match = matches[index]
    end

    return {
        reset = function(new_matches)
            matches = { unpack(new_matches) }

            table.sort(matches, function(match1, match2)
                if match1[1] ~= match2[1] then return match1[1] < match2[1] end
                return match1[2] < match2[2]
            end)

            for i, match in ipairs(matches) do
                if current_match ~= nil
                    and match[1] == current_match[1]
                    and match[2] == current_match[2] then
                    set_current_index(i)
                    return
                end
            end

            for i, match in ipairs(matches) do
                if (match[1] == cursor_pos[1] and match[2] >= cursor_pos[2])
                    or match[1] > cursor_pos[1] then
                    set_current_index(i)
                    return
                end
            end

            set_current_index(next(matches) == nil and 0 or 1)
        end,
        is_empty = function()
            return next(matches) == nil
        end,
        current_match = function()
            return matches[current_index]
        end,
        next_match = function()
            if current_index == 0 then return end
            set_current_index(current_index >= #matches and 1 or current_index + 1)
        end,
        prev_match = function()
            if current_index == 0 then return end
            set_current_index(current_index <= 1 and #matches or current_index - 1)
        end,
    }
end

return {
    regular_search = regular_search,
    search = search,
    make_context = make_context,
}
