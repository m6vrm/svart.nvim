local function replace_termcodes(string)
    return vim.api.nvim_replace_termcodes(string, true, false, true)
end

local keys = {
    ESC = replace_termcodes("<Esc>"),
    CR = replace_termcodes("<CR>"),
    BS = replace_termcodes("<BS>"),
    C_W = replace_termcodes("<C-W>"),
}

local function detect_label(char, last_label, labels)
    for _, label in ipairs(labels) do
        local prefix = last_label .. char

        if label:sub(1, prefix:len()) == prefix then
            return nil, prefix
        end
    end

    return char, last_label
end

local function wait_for_input(get_char, input_handler, get_labels)
    local query = ""
    local label = ""

    while true do
        local char = get_char(query, label)

        if char == nil then
            break
        end

        local labels = get_labels()
        char, label = detect_label(char, label, labels)

        if char == keys.BS then
            if label ~= "" then
                label = label:sub(1, -2)
            else
                query = query:sub(1, -2)
            end
        elseif char == keys.C_W then
            local delete_word_regex = [=[\v[[:keyword:]]\zs[^[:keyword:]]+$|[[:keyword:]]+$]=]

            if label ~= "" then
                label = vim.fn.substitute(label, delete_word_regex, "", "")
            else
                query = vim.fn.substitute(query, delete_word_regex, "", "")
            end
        elseif char ~= nil then
            query = query .. char
        end

        if not input_handler(query, label) then
            break
        end
    end
end

return {
    keys = keys,
    wait_for_input = wait_for_input,
}
