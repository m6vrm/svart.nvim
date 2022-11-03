local highlights = {
    SvartDimmedContent = { default = true, link = "Comment" },
    SvartMatch = { default = true, link = "Search" },
    SvartMatchCursor = { default = true, link = "Cursor" },
    SvartDimmedCursor = { default = true, link = "TermCursorNC" },
    SvartLabel = { default = true, link = "CurSearch" },
    SvartRegularPrompt = { default = true, link = "MoreMsg" },
    SvartErrorPrompt = { default = true, link = "ErrorMsg" },
}

for key, value in pairs(highlights) do
    vim.api.nvim_set_hl(0, key, value)
end

local commands = {
    { "Svart", function() require("svart").start() end },
    { "SvartRepeat", function() require("svart").do_repeat() end },
    { "SvartTest", function() require("svart.tests").run() end },
}

for _, command in ipairs(commands) do
    local name, action = unpack(command)
    vim.api.nvim_create_user_command(name, action, {})
end
