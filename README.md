![Preview](https://gitlab.com/madyanov/svart.nvim/uploads/6d878f54807efebc1508e9c84dabe155/output.gif)

Jump to any location with two keystrokes.

**Features**

- Bidirectional search
- [Smartcase](https://neovim.io/doc/user/options.html#'smartcase') support
- Really lightweight, one keymap to perform a single action

**Usage**

- Initiate search with `s`
- Start typing search pattern
- Type highlighted label to jump to corresponding location at any time
- Or press `Enter` to continue with regular (`/`) search
- Use `Backspace` to edit search pattern

Tested on Neovim 0.8.0.

**Default keymaps**

```lua
vim.keymap.set({ "n", "v" }, "s", function () require("svart").search() end, { silent = true })
```

**Default highlight groups**

```lua
SvartDim = { default = true, link = "Comment" },
SvartSearch = { default = true, link = "Search" },
SvartLabel = { default = true, link = "CurSearch" },
SvartMoreMsg = { default = true, link = "MoreMsg" },
SvartErrorMsg = { default = true, link = "ErrorMsg" },
```
