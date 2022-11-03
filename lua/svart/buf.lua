local function visible_bounds()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

local function line_at(line_nr)
    return vim.fn.getline(line_nr)
end

local function char_at(pos)
    local line_nr, col = unpack(pos)
    local line = line_at(line_nr)
    return line:sub(col, col)
end

return {
    visible_bounds = visible_bounds,
    line_at = line_at,
    char_at = char_at,
}
