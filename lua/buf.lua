function get_visible_bounds()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

function get_char_at_pos(pos)
    local line = vim.fn.getline(pos[1])
    local char = line:sub(pos[2], pos[2])
    return char
end

return {
    get_visible_bounds = get_visible_bounds,
    get_char_at_pos = get_char_at_pos,
}
