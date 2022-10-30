local highlights = {
    SvartDim = { default = true, link = "Comment" },
    SvartSearch = { default = true, link = "Search" },
    SvartCursor = { default = true, link = "Cursor" },
    SvartLabel = { default = true, link = "CurSearch" },
    SvartMoreMsg = { default = true, link = "MoreMsg" },
    SvartErrorMsg = { default = true, link = "ErrorMsg" },
}

for key, value in pairs(highlights) do
    vim.api.nvim_set_hl(0, key, value)
end

vim.keymap.set({ "n", "v" }, "s", function () require("svart").search() end, { silent = true })
