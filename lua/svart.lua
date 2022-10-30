local function replace_termcodes(string)
    return vim.api.nvim_replace_termcodes(string, true, false, true)
end

function get_visible_area()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

function save_state()
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

function get_matches(query, backwards)
    if query == "" then
        -- Don't search for empty strings
        return function () return nil end
    end

    local visible_area = get_visible_area()
    local saved_state = save_state()

    local search_flags = backwards and "b" or ""
    local search_stopline = backwards and visible_area.top or visible_area.bottom

    return function ()
        local pattern = get_search_pattern(query) .. "\\_."
        local match = vim.fn.searchpos(pattern, search_flags, search_stopline)

        if match[1] == 0 and match[2] == 0 then
            -- Restore cursor position after search
            -- since searchpos changes it and we can't use the "c" flag
            -- (this will result an infinite loop)
            saved_state.restore()
            return nil
        end

        return match
    end
end

function update_query(query, char)
    local esc_code = replace_termcodes("<Esc>")
    local cr_code = replace_termcodes("<CR>")
    local bs_code = replace_termcodes("<BS>")

    if char == esc_code then
        return nil
    elseif char == cr_code then
        -- Use standard / search on Enter
        if query ~= "" then
            local pattern = get_search_pattern(query)
            vim.api.nvim_feedkeys(replace_termcodes("/" .. pattern .. "<CR>"), "n", false)
        end

        return nil
    elseif char == bs_code then
        -- Remove last character on Backspace
        query = query:sub(1, -2)
    else
        -- Concatenate otherwise
        query = query .. char
    end

    return query
end

function jump_to_match(match)
    -- Cursor is (1,0)-indexed
    vim.api.nvim_win_set_cursor(0, { match[1], match[2] - 1 })
end

function generate_labels(matches, query)
    local labeled_matches = {}
    local query_len = query:len()

    local available_labels = "abcdefghijklmnopqrstuvwxyz[];'\\,./1234567890-="

    -- Filter available labels so that they won't collide with next possible searching character
    for i, match in ipairs(matches) do
        local line = vim.fn.getline(match[1])
        local next_character = line:sub(match[2] + query_len, match[2] + query_len)
        local pattern = next_character:lower():gsub("%p", "%%%1") -- Lua..
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

function echo_prompt(query, error)
    local highlight_group = error and "SvartErrorMsg" or "SvartMoreMsg"
    vim.api.nvim_echo({ { "> " }, { query, highlight_group} }, false, {})
end

function clear_prompt()
    vim.api.nvim_echo({}, false, {})
end

function search()
    -- Enter search
    local query = ""

    local highlighter = make_highlighter()
    highlighter.dim_content()

    local labeled_matches = {}
    local prompt_error = false

    -- Leave search handler
    local leave = function ()
        highlighter.restore_content()
        clear_prompt()
    end

    -- Recursion via feedkeys
    -- Workaround, since straight loop or recursion
    -- doesn't update highlighting on each typed character
    local queued_search = function ()
        vim.api.nvim_feedkeys(replace_termcodes("<Plug>SvartSearch"), "n", false)
    end
    local set_queued_search_keymap = function (search)
        vim.keymap.set({ "n", "v" }, "<Plug>SvartSearch", search, { silent = true })
    end

    local process_new_character = function ()
        highlighter.clear_search()
        echo_prompt(query, prompt_error)

        local char = vim.fn.getcharstr()

        -- Go to the label if current character is a label
        if labeled_matches[char] ~= nil then
            local match = labeled_matches[char]
            jump_to_match(match)
            return leave()
        end

        -- Reset labels and error from previous character search
        labeled_matches = {}
        prompt_error = false

        query = update_query(query, char)
        if query == nil then
            return leave()
        end

        local matches = {}
        -- First search forward from current cursor position
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
        -- elseif #matches == 1 then
        --     -- Immediately jump if there's only one match
        --     jump_to_match(matches[1])
        --     return leave()
        else
            -- Show labels if there's more than one match
            labeled_matches = generate_labels(matches, query)
            highlighter.highlight_labels(labeled_matches, query)
        end

        highlighter.highlight_matches(matches, query)

        queued_search()
    end

    set_queued_search_keymap(process_new_character)
    queued_search()
end

return {
    search = search,
}
