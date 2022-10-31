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
    local line = get_line(pos[1])
    return line:sub(pos[2], pos[2])
end

return {
    get_visible_bounds = get_visible_bounds,
    get_line = get_line,
    get_char_at_pos = get_char_at_pos,
}
