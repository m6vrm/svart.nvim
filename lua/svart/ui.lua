local buf = require("svart.buf")
local win = require("svart.win")

local function highlight_cursor(pos, namespace, hl_group)
    local char = win.run_on(pos.win_id, function()
        return buf.char_at(pos)
    end)

    vim.api.nvim_buf_set_extmark(
        vim.fn.winbufnr(pos.win_id),
        namespace,
        pos.line - 1,
        pos.col - 1,
        {
            virt_text = { { char or " ", hl_group } },
            virt_text_pos = "overlay"
        }
    )
end

local function prompt()
    return {
        show = function(query, label, error)
            local hl_group = error and "SvartErrorPrompt" or "SvartRegularPrompt"
            local gap = label == "" and "" or " "
            vim.api.nvim_echo({ { "> " }, { query, hl_group }, { gap .. label } }, false, {})
        end,
        clear = function()
            vim.api.nvim_echo({}, false, {})
        end,
    }
end

local function dim(win_ctx)
    local namespace = vim.api.nvim_create_namespace("svart-dim")
    local win_bounds = {}

    return {
        content = function()
            win_ctx.for_each(function(win_id)
                local bounds = buf.visible_bounds()
                win_bounds[win_id] = bounds

                vim.highlight.range(
                    vim.fn.winbufnr(win_id),
                    namespace,
                    "SvartDimmedContent",
                    { bounds.top - 1, 0 },
                    { bounds.bottom - 1, -1 }
                )

                highlight_cursor(win.cursor(), namespace, "SvartDimmedCursor")
            end)
        end,
        clear = function()
            for win_id, bounds in pairs(win_bounds) do
                vim.api.nvim_buf_clear_namespace(
                    vim.fn.winbufnr(win_id),
                    namespace,
                    bounds.top - 1,
                    bounds.bottom
                )
            end
        end,
    }
end

local function highlight()
    local namespace = vim.api.nvim_create_namespace("svart-search")
    local win_bounds = {}

    return {
        matches = function(matches, query)
            for _, win_matches in ipairs(matches.wins) do
                win_bounds[win_matches.win_id] = win_matches.bounds

                for _, match in ipairs(win_matches.list) do
                    vim.api.nvim_buf_add_highlight(
                        vim.fn.winbufnr(match.win_id),
                        namespace,
                        "SvartMatch",
                        match.line - 1,
                        match.col - 1,
                        match.col + #query - 1
                    )
                end
            end
        end,
        labels = function(labeled_matches, query)
            for label, match in labeled_matches.pairs() do
                vim.api.nvim_buf_set_extmark(
                    vim.fn.winbufnr(match.win_id),
                    namespace,
                    match.line - 1,
                    match.col - 1 + #query,
                    {
                        strict = false,
                        virt_text = { { label, "SvartLabel" } },
                        virt_text_pos = "overlay",
                    }
                )
            end
        end,
        cursor = function(pos)
            if pos == nil then return end
            highlight_cursor(pos, namespace, "SvartMatchCursor")
        end,
        clear = function()
            for win_id, bounds in pairs(win_bounds) do
                vim.api.nvim_buf_clear_namespace(
                    vim.fn.winbufnr(win_id),
                    namespace,
                    bounds.top - 1,
                    bounds.bottom
                )
            end
        end,
    }
end

local function redraw()
    vim.cmd.redraw()
end

return {
    prompt = prompt,
    dim = dim,
    highlight = highlight,
    redraw = redraw,
}
