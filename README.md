![Preview](https://gitlab.com/madyanov/svart.nvim/uploads/e18283000accf0281d34ac77b1a46aa4/output.gif)

Jump to any location with few keystrokes.

**Features**

- Bidirectional search
- Multi-window navigation
- [Smartcase](https://neovim.io/doc/user/options.html#'smartcase') support
- "Steady" deterministic labels
- Search by regular expression

**Installation**

Install plugin and add keymaps:

```lua
vim.keymap.set({ "n", "x", "o" }, "s", "<Cmd>Svart<CR>")        -- begin exact search
vim.keymap.set({ "n", "x", "o" }, "S", "<Cmd>SvartRegex<CR>")   -- begin regex search
vim.keymap.set({ "n", "x", "o" }, "gs", "<Cmd>SvartRepeat<CR>") -- repeat with last accepted query
```

**Usage**

- Initiate search with `s` or `S`
- Start typing search query
- Type highlighted label to jump to corresponding location at any time
- Or press `C-N` or `C-P` to select location
    - Press `Enter` to jump to the selected location and continue with regular (`/`) search
- Use `Backspace`, `C-W`, `C-U` to edit search query

**Configuration**

> **Note:** There's no need to call `svart.configure` if you don't want to change configuration defaults.

```lua
local svart = require("svart")

svart.configure({
    key_cancel = "<Esc>",       -- cancel search
    key_delete_char = "<BS>",   -- delete query char
    key_delete_word = "<C-W>",  -- delete query word
    key_delete_query = "<C-U>", -- delete whole query
    key_best_match = "<CR>",    -- jump to the best match
    key_next_match = "<C-N>",   -- select next match
    key_prev_match = "<C-P>",   -- select prev match

    label_atoms = "jfkdlsahgnuvrbytmiceoxwpqz", -- allowed label chars
    label_location = -1,                        -- label location relative to the match
                                                -- positive: relative to the start of the match
                                                -- 0 or negative: relative to the end of the match
    label_max_len = 2,                          -- max label length
    label_min_query_len = 1,                    -- min query length required to show labels
    label_hide_irrelevant = true,               -- hide irrelevant labels after start typing label to go to
    label_conflict_foresight = 3,               -- number of chars from the start of the match to discard from labels pool

    search_update_register = true, -- update search (/) register with last used query after accepting match
    search_wrap_around = true,     -- wrap around when navigating to next/prev match
    search_multi_window = true,    -- search in multiple windows

    ui_dim_content = true, -- dim buffer content during search
})
```

**Highlight groups**

```lua
SvartDimmedContent = { default = true, link = "Comment" },
SvartMatch = { default = true, link = "Search" },
SvartMatchCursor = { default = true, link = "Cursor" },
SvartDimmedCursor = { default = true, link = "TermCursorNC" },
SvartLabel = { default = true, link = "IncSearch" },
SvartPrompt = { default = true, link = "MoreMsg" },
SvartErrorPrompt = { default = true, link = "ErrorMsg" },
```

**Contributing**

1. Add new tests to the `lua/svart/tests.lua`
2. Run tests with `:SvartTest` command
