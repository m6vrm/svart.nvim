local buf = require("svart.buf")
local win = require("svart.win")

local function highlight_cursor(pos, namespace, hl_group)
    if pos == nil then return end

    local char = buf.char_at(pos)
    local line, col = unpack(pos)

    vim.api.nvim_buf_set_extmark(
        0,
        namespace,
        line - 1,
        col - 1,
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

local function dim()
    local namespace = vim.api.nvim_create_namespace("svart-dim")
    local bounds = buf.visible_bounds()

    return {
        content = function()
            vim.highlight.range(
                0,
                namespace,
                "SvartDimmedContent",
                { bounds.top - 1, 0 },
                { bounds.bottom - 1, -1 }
            )

            highlight_cursor(win.cursor_pos(), namespace, "SvartDimmedCursor")
        end,
        clear = function()
            vim.api.nvim_buf_clear_namespace(
                0,
                namespace,
                bounds.top - 1,
                bounds.bottom
            )
        end,
    }
end

local function highlight()
    local namespace = vim.api.nvim_create_namespace("svart-search")
    local bounds = buf.visible_bounds()

    return {
        matches = function(matches, query)
            for _, match in ipairs(matches) do
                local line, col = unpack(match)

                vim.api.nvim_buf_add_highlight(
                    0,
                    namespace,
                    "SvartMatch",
                    line - 1,
                    col - 1,
                    col + #query - 1
                )
            end
        end,
        labels = function(labeled_matches, query)
            for label, match in labeled_matches.pairs() do
                local line, col = unpack(match)
                local i = 0

                for char in label:gmatch(".") do
                    vim.api.nvim_buf_set_extmark(
                        0,
                        namespace,
                        line - 1,
                        col - 1 + #query + i,
                        {
                            strict = false,
                            virt_text_win_col = col - 1 + #query + i,
                            virt_text = { { char, "SvartLabel" } },
                            virt_text_pos = "overlay",
                        }
                    )

                    i = i + 1
                end
            end
        end,
        cursor = function(pos)
            highlight_cursor(pos, namespace, "SvartMatchCursor")
        end,
        clear = function()
            vim.api.nvim_buf_clear_namespace(
                0,
                namespace,
                bounds.top - 1,
                bounds.bottom
            )
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
