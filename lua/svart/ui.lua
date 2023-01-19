local buf = require("svart.buf")
local win = require("svart.win")

local function highlight_cursor(pos, namespace, hl_group)
    local char = win.run_on(pos.win_id, function()
        return buf.char_at(pos)
    end)

    win.buf_nr(pos.win_id, function(buf_nr)
        vim.api.nvim_buf_set_extmark(
            buf_nr,
            namespace,
            pos.line - 1,
            pos.col - 1,
            {
                virt_text = { { char or " ", hl_group } },
                virt_text_pos = "overlay"
            }
        )
    end)
end

local M = {}

function M.prompt()
    local this = {}

    this.show = function(query, label, error)
        local hl_group = error and "SvartErrorPrompt" or "SvartPrompt"
        local gap = label == "" and "" or " "
        vim.api.nvim_echo({ { "> " }, { query, hl_group }, { gap .. label } }, false, {})
    end

    this.clear = function()
        -- workaround to fix the need for
        -- an extra keystroke when cmdheight=0
        -- (issue #4)
        local cmdheight = vim.opt.cmdheight:get()
        vim.opt.cmdheight = math.max(1, cmdheight)

        vim.api.nvim_echo({}, false, {})

        vim.opt.cmdheight = cmdheight
    end

    return this
end

function M.dim(win_ctx)
    local namespace = vim.api.nvim_create_namespace("svart-dim")
    local win_bounds = {}

    local this = {}

    this.content = function()
        win_ctx.for_each(function(win_id)
            local bounds = buf.visible_bounds()
            win_bounds[win_id] = bounds

            win.buf_nr(win_id, function(buf_nr)
                vim.highlight.range(
                    buf_nr,
                    namespace,
                    "SvartDimmedContent",
                    { bounds.top - 1, 0 },
                    { bounds.bottom - 1, -1 }
                )
            end)

            highlight_cursor(win.cursor(), namespace, "SvartDimmedCursor")
        end)
    end

    this.clear = function()
        for win_id, bounds in pairs(win_bounds) do
            win.buf_nr(win_id, function(buf_nr)
                vim.api.nvim_buf_clear_namespace(
                    buf_nr,
                    namespace,
                    bounds.top - 1,
                    bounds.bottom
                )
            end)
        end
    end

    return this
end

function M.highlight(config)
    local namespace = vim.api.nvim_create_namespace("svart-search")
    local win_bounds = {}

    local this = {}

    this.matches = function(matches)
        for _, win_matches in ipairs(matches.wins) do
            win_bounds[win_matches.win_id] = win_matches.bounds

            for _, match in ipairs(win_matches.list) do
                win.buf_nr(match.win_id, function(buf_nr)
                    vim.api.nvim_buf_add_highlight(
                        buf_nr,
                        namespace,
                        "SvartMatch",
                        match.line - 1,
                        match.col - 1,
                        match.col + match.len - 1
                    )
                end)
            end
        end
    end

    this.labels = function(labeled_matches)
        for label, match in labeled_matches.pairs() do
            local col = config.label_location > 0
                and match.col + config.label_location - 2
                or match.col + match.len + -config.label_location - 2

            win.buf_nr(match.win_id, function(buf_nr)
                vim.api.nvim_buf_set_extmark(
                    buf_nr,
                    namespace,
                    match.line - 1,
                    col,
                    {
                        strict = false,
                        virt_text = { { label, "SvartLabel" } },
                        virt_text_pos = "overlay",
                    }
                )
            end)
        end
    end

    this.cursor = function(pos)
        if pos == nil then return end
        highlight_cursor(pos, namespace, "SvartMatchCursor")
    end

    this.clear = function()
        for win_id, bounds in pairs(win_bounds) do
            win.buf_nr(win_id, function(buf_nr)
                vim.api.nvim_buf_clear_namespace(
                    buf_nr,
                    namespace,
                    bounds.top - 1,
                    bounds.bottom
                )
            end)
        end
    end

    return this
end

function M.redraw()
    vim.cmd.redraw()
end

return M
