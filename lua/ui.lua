local buf = require("buf")
local win = require("win")

local highlight_namespace = vim.api.nvim_create_namespace("svart-highlight")
local dim_namespace = vim.api.nvim_create_namespace("svart-dim")

local function highlight_cursor(namespace, highlight_group, pos)
    local pos = pos or win.get_cursor_pos()
    local char = buf.get_char_at_pos(pos)

    vim.api.nvim_buf_set_extmark(
        0,
        namespace,
        pos[1] - 1,
        pos[2] - 1,
        {
            virt_text = { { char or " ", highlight_group} },
            virt_text_pos = "overlay"
        }
    )
end

local function prompt()
    return {
        show = function (query, error)
            local highlight_group = error and "SvartErrorPrompt" or "SvartRegularPrompt"
            vim.api.nvim_echo({ { "svart> " }, { query, highlight_group} }, false, {})
        end,
        clear = function ()
            vim.api.nvim_echo({}, false, {})
        end,
    }
end

local function dim()
    local bounds = buf.get_visible_bounds()

    return {
        content = function ()
            vim.highlight.range(
                0,
                dim_namespace,
                "SvartDimmedContent",
                { bounds.top - 1, 0 },
                { bounds.bottom - 1, -1 }
            )

            highlight_cursor(dim_namespace, "SvartDimmedCursor")
        end,
        clear = function ()
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
    local bounds = buf.get_visible_bounds()

    return {
        matches = function (matches, query)
            local query_len = query:len()
            local match = matches[1]

            if match ~= nil then
                vim.api.nvim_buf_add_highlight(
                    0,
                    highlight_namespace,
                    "SvartSearch",
                    match[1] - 1,
                    match[2] - 1,
                    match[2] + query_len - 1
                )
            end
        end,
        labels = function (labeled_matches, query)
            local query_len = query:len()

            for label, match in pairs(labeled_matches) do
                vim.api.nvim_buf_set_extmark(
                    0,
                    highlight_namespace,
                    match[1] - 1,
                    match[2] - 1, -- + query_len
                    {
                        virt_text = { { label, "SvartLabel" } },
                        virt_text_pos = "overlay"
                    }
                )
            end
        end,
        cursor = function (pos)
            highlight_cursor(highlight_namespace, "SvartSearchCursor", pos)
        end,
        clear = function ()
            vim.api.nvim_buf_clear_namespace(
                0,
                highlight_namespace,
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
