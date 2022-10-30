<figure class="video_container">
    <iframe src="https://i.imgur.com/dRU8MkA.mp4" frameborder="0" allowfullscreen="true" height="570" width="700"></iframe>
</figure>

Jump to any location with two keystrokes.

**Features**

- Bidirectional search
- [Smartcase](https://neovim.io/doc/user/options.html#'smartcase') support
- Really lightweight, one keymap to perform a single action

**Usage**

- Initiate search with `s`
- Start typing search pattern
- Type highlighted label to jump to corresponding location at any time
- Or press `Enter` to continue with stadard `/` search
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
