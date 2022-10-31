local function replace_termcodes(string)
    return vim.api.nvim_replace_termcodes(string, true, false, true)
end

local keys = {
    ESC = replace_termcodes("<Esc>"),
    CR = replace_termcodes("<CR>"),
    BS = replace_termcodes("<BS>"),
    C_W = replace_termcodes("<C-W>"),
}

local function wait_for_input(get_char, input_handler)
    local input = ""

    while true do
        local char = get_char(input)

        if char == nil then
            break
        end

        if char == keys.BS then
            input = input:sub(1, -2)
        elseif char == keys.C_W then
            local delete_last_word_regex = [=[\v[[:keyword:]]\zs[^[:keyword:]]+$|[[:keyword:]]+$]=]
            input = vim.fn.substitute(input, delete_last_word_regex, "", "")
        else
            input = input .. char
        end

        input_handler(input)
    end
end

return {
    keys = keys,
    wait_for_input = wait_for_input,
}
