local utils = require("svart.utils")
local buf = require("svart.buf")
local win = require("svart.win")

local function search_regex(query)
    return "\\V" .. vim.fn.escape(query, "\\") .. "\\_."
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
        -- capture match under cursor on first search
        local cursor_match_flag = first_search and not backwards and "c" or ""
        first_search = false

        local regex = search_regex(query)
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
    if query == "" then return end

    local saved_view_state = win.save_view_state()
    local regex = search_regex(query)

    vim.cmd("/" .. regex)

    saved_view_state.restore()
end

local function search(query)
    local bounds = buf.visible_bounds()
    local matches = {}

    -- search forward
    for match in directional_search(query, false, bounds) do
        table.insert(matches, match)
    end

    -- then search backwards
    for match in directional_search(query, true, bounds) do
        table.insert(matches, match)
    end

    return matches
end

local function make_context(cursor, wrap_around)
    local matches = {}
    local current_idx = 0
    local current_match = nil

    local set_current_index = function(idx)
        current_idx = idx
        current_match = matches[idx]
    end

    return {
        reset = function(new_matches)
            matches = { unpack(new_matches) }

            -- sort matches by line number for easier navigation
            table.sort(matches, function(match1, match2)
                if match1[1] ~= match2[1] then return match1[1] < match2[1] end
                return match1[2] < match2[2]
            end)

            -- don't change current match if it's equal to the previous one
            for i, match in ipairs(matches) do
                if current_match ~= nil
                    and match[1] == current_match[1]
                    and match[2] == current_match[2] then
                    set_current_index(i)
                    return
                end
            end

            -- or set current match as the first match after the cursror
            -- todo: use nearest match to the cursor?
            for i, match in ipairs(matches) do
                if (match[1] == cursor[1] and match[2] >= cursor[2])
                    or match[1] > cursor[1] then
                    set_current_index(i)
                    return
                end
            end

            -- or set current match to the first one
            set_current_index(next(matches) == nil and 0 or 1)
        end,
        is_empty = function()
            return next(matches) == nil
        end,
        best_match = function()
            return matches[current_idx]
        end,
        next_match = function()
            -- next match with wraparound
            if current_idx == 0 then return end
            local last_idx = wrap_around and 1 or #matches
            set_current_index(current_idx >= #matches and last_idx or current_idx + 1)
        end,
        prev_match = function()
            -- previous match with wraparound
            if current_idx == 0 then return end
            local last_idx = wrap_around and #matches or 1
            set_current_index(current_idx <= 1 and last_idx or current_idx - 1)
        end,
    }
end

local function test()
    local tests = require("svart.tests")

    -- search_regex
    do
        local regex = search_regex([[ \ test \ ]])
        tests.assert_eq(regex, [[\V \\ test \\ \_.]])
    end

    -- make_context
    do
        -- empty
        local ctx = make_context({ 2, 1 }, true)
        assert(ctx.is_empty())
        tests.assert_eq(ctx.best_match(), nil)

        -- filled
        ctx.reset({ { 1, 1 }, { 3, 1 }, { 4, 1 } })
        assert(not ctx.is_empty())
        tests.assert_eq(ctx.best_match(), { 3, 1 })

        -- next
        ctx.next_match()
        tests.assert_eq(ctx.best_match(), { 4, 1 })

        -- wrap around
        ctx.next_match()
        tests.assert_eq(ctx.best_match(), { 1, 1 })
        ctx.prev_match()
        tests.assert_eq(ctx.best_match(), { 4, 1 })

        -- prev
        ctx.prev_match()
        tests.assert_eq(ctx.best_match(), { 3, 1 })

        -- preseve best match
        ctx.reset({ { 1, 1 }, { 3, 1 } })
        tests.assert_eq(ctx.best_match(), { 3, 1 })

        -- clear best match
        ctx.reset({ { 1, 1 } })
        tests.assert_eq(ctx.best_match(), { 1, 1 })

        -- wrap around disabled
        ctx = make_context({ 2, 1 }, false)
        ctx.reset({ { 1, 1 }, { 3, 1 } })

        ctx.next_match()
        tests.assert_eq(ctx.best_match(), { 3, 1 })
        ctx.next_match()
        tests.assert_eq(ctx.best_match(), { 3, 1 })

        ctx.prev_match()
        tests.assert_eq(ctx.best_match(), { 1, 1 })
        ctx.prev_match()
        tests.assert_eq(ctx.best_match(), { 1, 1 })
    end
end

return {
    regular_search = regular_search,
    search = search,
    make_context = make_context,
    test = test,
}
