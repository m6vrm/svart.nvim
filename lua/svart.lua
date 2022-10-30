local function replace_termcodes(string)
    return vim.api.nvim_replace_termcodes(string, true, false, true)
end

function get_visible_area()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

function save_view_state()
    local view = vim.fn.winsaveview()

    return {
        restore = function ()
            vim.fn.winrestview(view)
        end,
    }
end

function get_search_pattern(query)
    return "\\V" .. vim.fn.escape(query, "\\")
end

function begin_regular_search(query)
    if query == "" then
        return
    end

    local saved_view_state = save_view_state()
    local pattern = get_search_pattern(query)
    vim.cmd("/" .. pattern)
    saved_view_state.restore()
end

function get_matches(query, backwards)
    if query == "" then
        return function () return nil end
    end

    local visible_area = get_visible_area()
    local saved_view_state = save_view_state()

    local search_flags = backwards and "b" or ""
    local search_stopline = backwards and visible_area.top or visible_area.bottom

    return function ()
        local pattern = get_search_pattern(query) .. "\\_."
        local match = vim.fn.searchpos(pattern, search_flags, search_stopline)

        if match[1] == 0 and match[2] == 0 then
            -- Restore cursor pos after search
            -- since searchpos changes it and we can't use the "c" flag
            -- (this will result an infinite loop)
            saved_view_state.restore()
            return nil
        end

        return match
    end
end

function get_char_at_pos(pos)
    local line = vim.fn.getline(pos[1])
    local char = line:sub(pos[2], pos[2])
    return char
end

function generate_labels(matches, query)
    local labeled_matches = {}
    local query_len = query:len()

    local available_labels = "jfkdlsahgnuvrbytmiceoxwpqz[];'\\,./1234567890-="

    -- Filter available labels so that they won't collide with next possible searching char
    for i, match in ipairs(matches) do
        local next_char = get_char_at_pos({ match[1], match[2] + query_len })
        local pattern = next_char:lower():gsub("%p", "%%%1") -- Lua..
        available_labels = available_labels:gsub(pattern, "")
    end

    -- Mark matches with remaining labels
    for i, match in ipairs(matches) do
        if available_labels == "" then
            break
        end

        local label = available_labels:sub(1, 1)
        available_labels = available_labels:sub(2)
        labeled_matches[label] = match
    end

    return labeled_matches
end

function make_highlighter()
    local visible_area = get_visible_area()
    local search_namespace = vim.api.nvim_create_namespace("svart-search")
    local content_namespace = vim.api.nvim_create_namespace("svart-content")

    return {
        dim_content = function ()
            vim.highlight.range(
                0,
                content_namespace,
                "SvartDim",
                { visible_area.top - 1, 0 },
                { visible_area.bottom - 1, -1 }
            )
        end,
        restore_content = function ()
            vim.api.nvim_buf_clear_namespace(
                0,
                content_namespace,
                visible_area.top - 1,
                visible_area.bottom
            )
        end,
        highlight_matches = function (matches, query)
            local query_len = query:len()

            for i, match in ipairs(matches) do
                vim.api.nvim_buf_add_highlight(
                    0,
                    search_namespace,
                    "SvartSearch",
                    match[1] - 1,
                    match[2] - 1,
                    match[2] + query_len - 1
                )
            end
        end,
        highlight_labels = function (labeled_matches, query)
            local query_len = query:len()

            for label, match in pairs(labeled_matches) do
                vim.api.nvim_buf_set_extmark(
                    0,
                    search_namespace,
                    match[1] - 1,
                    match[2] + query_len - 1,
                    {
                        virt_text = { { label, "SvartLabel" } },
                        virt_text_pos = "overlay"
                    }
                )
            end
        end,
        highlight_cursor = function (match)
            local char = get_char_at_pos(match)

            vim.api.nvim_buf_set_extmark(
                0,
                search_namespace,
                match[1] - 1,
                match[2] - 1,
                {
                    virt_text = { { char or " ", "SvartCursor" } },
                    virt_text_pos = "overlay"
                }
            )
        end,
        clear_search = function ()
            vim.api.nvim_buf_clear_namespace(
                0,
                search_namespace,
                visible_area.top - 1,
                visible_area.bottom
            )
        end,
    }
end

function jump_to_match(match)
    -- Cursor is (1,0)-indexed
    vim.api.nvim_win_set_cursor(0, { match[1], match[2] - 1 })
end

function show_prompt(query, error)
    local highlight_group = error and "SvartErrorMsg" or "SvartMoreMsg"
    vim.api.nvim_echo({ { "svart> " }, { query, highlight_group} }, false, {})
end

function clear_prompt()
    vim.api.nvim_echo({}, false, {})
end

function search()
    local esc_code = replace_termcodes("<Esc>")
    local cr_code = replace_termcodes("<CR>")
    local bs_code = replace_termcodes("<BS>")

    -- Enter search
    local query = ""
    local highlighter = make_highlighter()

    local matches = {}
    local labeled_matches = {}
    local prompt_error = false

    highlighter.dim_content()

    while true do
        show_prompt(query, prompt_error)

        local char = vim.fn.getcharstr()
        highlighter.clear_search()

        -- Cancel on Esc
        if char == esc_code then
            break
        end

        -- Go to the best (first) match on Enter and begin regular (/) search
        if char == cr_code then
            if matches[1] ~= nil then
                jump_to_match(matches[1])
                begin_regular_search(query)
            end

            break
        end

        -- Go to the label if current char is a label
        if labeled_matches[char] ~= nil then
            local match = labeled_matches[char]
            jump_to_match(match)
            break
        end

        if char == bs_code then
            -- Remove last char on Backspace
            query = query:sub(1, -2)
        else
            -- Concatenate otherwise
            query = query .. char
        end

        -- Reset state from previous char search
        matches = {}
        labeled_matches = {}
        prompt_error = false

        -- First search forward from current cursor pos
        for match in get_matches(query, false) do
            table.insert(matches, match)
        end
        -- Then search backwards and merge results
        for match in get_matches(query, true) do
            table.insert(matches, match)
        end

        if #matches == 0 then
            -- Nothing found, highlight prompt
            prompt_error = true
        else
            -- Highlight possible matches
            highlighter.highlight_matches(matches, query)

            -- Show labels if there's more than one match
            labeled_matches = generate_labels(matches, query)
            highlighter.highlight_labels(labeled_matches, query)

            -- Highlight fake cursor
            highlighter.highlight_cursor(matches[1])

            vim.cmd([[ redraw ]])
        end
    end

    -- Leave search
    highlighter.restore_content()
    clear_prompt()
end

return {
    search = search,
}
