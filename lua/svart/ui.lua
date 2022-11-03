local buf = require("svart.buf")
local win = require("svart.win")

local search_namespace = vim.api.nvim_create_namespace("svart-search")
local dim_namespace = vim.api.nvim_create_namespace("svart-dim")

local function highlight_cursor(pos)
    local namespace = pos and search_namespace or dim_namespace
    local hl_group = pos and "SvartMatchCursor" or "SvartDimmedCursor"

    local pos = pos or win.cursor_pos()
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
            vim.api.nvim_echo({ { "svart> " }, { query, hl_group }, { gap .. label } }, false, {})
        end,
        clear = function()
            vim.api.nvim_echo({}, false, {})
        end,
    }
end

local function dim()
    local bounds = buf.visible_bounds()

    return {
        content = function()
            vim.highlight.range(
                0,
                dim_namespace,
                "SvartDimmedContent",
                { bounds.top - 1, 0 },
                { bounds.bottom - 1, -1 }
            )

            highlight_cursor()
        end,
        clear = function()
            vim.api.nvim_buf_clear_namespace(
                0,
                dim_namespace,
                bounds.top - 1,
                bounds.bottom
            )
        end,
    }
end

local function highlight()
    local bounds = buf.visible_bounds()

    return {
        matches = function(matches, query)
            for _, match in ipairs(matches) do
                local line, col = unpack(match)

                vim.api.nvim_buf_add_highlight(
                    0,
                    search_namespace,
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
                        search_namespace,
                        line - 1,
                        col - 1 + #query + i,
                        {
                            strict = false,
                            virt_text = { { char, "SvartLabel" } },
                            virt_text_pos = "overlay",
                        }
                    )

                    i = i + 1
                end
            end
        end,
        cursor = function(pos)
            highlight_cursor(pos)
        end,
        clear = function()
            vim.api.nvim_buf_clear_namespace(
                0,
                search_namespace,
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
