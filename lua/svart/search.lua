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

local function search(win_ctx, query)
    local matches = {
        count = 0,
        wins = {},
    }

    win_ctx.for_each(function(win_id, current_win_id)
        local bounds = buf.visible_bounds()
        local cursor = win.cursor()

        local win_matches = {
            win_id = win_id,
            bounds = bounds,
            cursor = cursor,
            list = {},
        }

        -- search forward
        for match in directional_search(query, false, bounds) do
            local line, col = unpack(match)
            table.insert(win_matches.list, { win_id = win_id, line = line, col = col })
        end

        -- then search backwards
        for match in directional_search(query, true, bounds) do
            local line, col = unpack(match)
            table.insert(win_matches.list, { win_id = win_id, line = line, col = col })
        end

        matches.count = matches.count + #win_matches.list
        table.insert(matches.wins, win_matches)
    end)

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
            matches = {}

            -- collect matches from all windows
            for _, win_matches in ipairs(new_matches.wins) do
                local matches_copy = { unpack(win_matches.list) }

                -- sort matches by line number for easier navigation
                table.sort(matches_copy, function(match1, match2)
                    if match1.line ~= match2.line then return match1.line < match2.line end
                    return match1.col < match2.col
                end)

                for _, match in ipairs(matches_copy) do
                    table.insert(matches, match)
                end
            end

            -- don't change current match if it's equal to the previous one
            for i, match in ipairs(matches) do
                if current_match ~= nil
                    and match.win_id == current_match.win_id
                    and match.line == current_match.line
                    and match.col == current_match.col then
                    set_current_index(i)
                    return
                end
            end

            -- or set current match to the first match after the cursror
            local last_idx = 0

            for i, match in ipairs(matches) do
                if (match.line == cursor.line and match.col >= cursor.col)
                    or match.line > cursor.line then
                    set_current_index(i)
                    return
                end

                last_idx = i
            end

            -- or set current match to the nearest to the cursor
            set_current_index(last_idx)
        end,
        is_empty = function()
            return next(matches) == nil
        end,
        best_match = function()
            return matches[current_idx]
        end,
        next_match = function()
            if current_idx == 0 then return end
            local last_idx = wrap_around and 1 or #matches
            set_current_index(current_idx >= #matches and last_idx or current_idx + 1)
        end,
        prev_match = function()
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
