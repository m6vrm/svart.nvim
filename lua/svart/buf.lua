local M = {}

function M.visible_bounds()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

function M.line_at(line_nr)
    return vim.fn.getline(line_nr)
end

function M.char_at(pos)
    local line = M.line_at(pos.line)
    return line:sub(pos.col, pos.col)
end

return M
