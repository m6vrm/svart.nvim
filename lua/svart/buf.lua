local function get_visible_bounds()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

local function get_line(line_nr)
    return vim.fn.getline(line_nr)
end

local function get_char_at_pos(pos)
    local line_nr, col = unpack(pos)
    local line = get_line(line_nr)
    return line:sub(col, col)
end

return {
    get_visible_bounds = get_visible_bounds,
    get_line = get_line,
    get_char_at_pos = get_char_at_pos,
}
