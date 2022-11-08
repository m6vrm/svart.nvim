local M = {}

function M.visible_bounds()
    return {
        top = vim.fn.line("w0"),
        bottom = vim.fn.line("w$"),
    }
end

function M.char_at(pos)
    local line = vim.fn.getline(pos.line)
    return line:sub(pos.col, pos.col)
end

return M
