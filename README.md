![Preview](https://gitlab.com/madyanov/svart.nvim/uploads/478fa6119b0dc551fb270f29a5fb0ae1/output.gif)

Jump to any location with few keystrokes.

**Features**

- Bidirectional search
- Multi-window navigation
- [Smartcase](https://neovim.io/doc/user/options.html#'smartcase') support
- "Steady" deterministic labels

**Installation**

Install plugin and add keymaps:

```lua
vim.keymap.set({ "n", "x", "o" }, "s", "<Cmd>Svart<CR>")       -- begin search
vim.keymap.set({ "n", "x", "o" }, "S", "<Cmd>SvartRepeat<CR>") -- repeat with last searched query
```

**Usage**

- Initiate search with `s`
- Start typing search query
- Type highlighted label to jump to corresponding location at any time
- Or press `C-N` or `C-P` to select location
    - Press `Enter` to jump to the selected location and continue with regular (`/`) search
- Use `Backspace` and `C-W` to edit search query

**Configuration**

```lua
local svart = require("svart")

svart.configure({
    key_cancel = "<Esc>",      -- cancel search
    key_delete_char = "<BS>",  -- delete query char
    key_delete_word = "<C-W>", -- delete query word
    key_best_match = "<CR>",   -- jump to the best match
    key_next_match = "<C-N>",  -- select next match
    key_prev_match = "<C-P>",  -- select prev match

    label_atoms = "jfkdlsahgnuvrbytmiceoxwpqz", -- allowed label chars
    label_max_len = 2,                          -- max label length
    label_min_query_len = 1,                    -- min query length needed to show labels
    label_hide_irrelevant = true,               -- hide irrelevant labels after start typing label to go to

    search_begin_regular = true, -- begin regular (/) search after accepting match
    search_wrap_around = true,   -- wrap around when navigating to next/prev match
    search_multi_window = true,  -- search in multiple windows
})
```

**Highlight groups**

```lua
SvartDimmedContent = { default = true, link = "Comment" },
SvartMatch = { default = true, link = "Search" },
SvartMatchCursor = { default = true, link = "Cursor" },
SvartDimmedCursor = { default = true, link = "TermCursorNC" },
SvartLabel = { default = true, link = "IncSearch" },
SvartRegularPrompt = { default = true, link = "MoreMsg" },
SvartErrorPrompt = { default = true, link = "ErrorMsg" },
```

**Contributing**

1. Add new tests to the `lua/svart/tests.lua`
2. Run tests with `:SvartTest` command
