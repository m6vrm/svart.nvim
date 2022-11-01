local highlights = {
    SvartDimmedContent = { default = true, link = "Comment" },
    SvartSearch = { default = true, link = "Search" },
    SvartSearchCursor = { default = true, link = "Cursor" },
    SvartDimmedCursor = { default = true, link = "TermCursorNC" },
    SvartLabel = { default = true, link = "CurSearch" },
    SvartRegularPrompt = { default = true, link = "MoreMsg" },
    SvartErrorPrompt = { default = true, link = "ErrorMsg" },
}

for key, value in pairs(highlights) do
    vim.api.nvim_set_hl(0, key, value)
end

vim.keymap.set({ "n", "v" }, "s", function () require("svart").begin_search() end, { silent = true })
