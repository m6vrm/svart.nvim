local highlights = {
    SvartDimmedContent = { default = true, link = "Comment" },
    SvartMatch = { default = true, link = "Search" },
    SvartMatchCursor = { default = true, link = "Cursor" },
    SvartDimmedCursor = { default = true, link = "TermCursorNC" },
    SvartLabel = { default = true, link = "IncSearch" },
    SvartPrompt = { default = true, link = "MoreMsg" },
    SvartErrorPrompt = { default = true, link = "ErrorMsg" },
}

for key, value in pairs(highlights) do
    vim.api.nvim_set_hl(0, key, value)
end

local commands = {
    Svart = function() require("svart").search() end,
    SvartRepeat = function() require("svart").do_repeat() end,
    SvartTest = function()
        local module = "svart.tests"
        package.loaded[module] = nil
        require(module).run()
    end,
}

for command, action in pairs(commands) do
    vim.api.nvim_create_user_command(command, action, {})
end
