local config = require("svart.config")
local utils = require("svart.utils")

local function replace_termcodes(string)
    return vim.api.nvim_replace_termcodes(string, true, false, true)
end

local function is_printable(char)
    local char_nr = vim.fn.char2nr(char)

    return type(char_nr) == "number"
       and ((char_nr >= 32 and char_nr <= 126) or char_nr > 159)
end

local function is_label(possible_label, labels)
    for _, label in ipairs(labels) do
        if utils.string_prefix(label, possible_label) then
            return true
        end
    end

    return false
end

local M = {}

M.keys = {
    cancel = replace_termcodes(config.key_cancel),
    delete_char = replace_termcodes(config.key_delete_char),
    delete_word = replace_termcodes(config.key_delete_word),
    best_match = replace_termcodes(config.key_best_match),
    next_match = replace_termcodes(config.key_next_match),
    prev_match = replace_termcodes(config.key_prev_match),
}

function M.wait_for_input(query, get_labels, get_char, input_handler)
    local query = query or ""
    local label = ""

    -- trigger handler once if query is not empty
    if query ~= "" then
        input_handler(query, label)
    end

    while true do
        local char = get_char(query, label)

        if char == nil then
            break
        end

        if char == M.keys.delete_char then
            -- delete last char form label or query
            if label ~= "" then
                label = label:sub(1, -2)
            else
                query = query:sub(1, -2)
            end
        elseif char == M.keys.delete_word then
            -- delete whole label or last char from query
            local delete_word_regex = [=[\v[[:keyword:]]\zs[^[:keyword:]]+$|[[:keyword:]]+$]=]

            if label ~= "" then
                label = vim.fn.substitute(label, delete_word_regex, "", "")
            else
                query = vim.fn.substitute(query, delete_word_regex, "", "")
            end
        end

        if is_printable(char) then
            local labels = get_labels()

            if is_label(label .. char, labels) then
                label = label .. char
            elseif label == "" then
                query = query .. char
            end
        end

        if not input_handler(query, label) then break end
    end
end

return M
