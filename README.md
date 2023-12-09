This my minimal, clutter-free, less-than-a-million-keymaps Neovim configuration for day-to-day programming.

> Best used with Kitty terminal (or Alacritty if you prefer that) which runs a powerline font (or at least,
> a font that supports ligatures)

Here are a few programming languages I usually write in:
- C++/C (and OpenFOAM code)
- Python, Lua as scripting languages
- HTML, CSS, JavaScript for web development
- Markdown for writing READMEs and other documentation, LATEX for academic writing
- GdScript, GLSL for game development
- Obviously, Bash for shell scripting

Want to get started? -> Press `<space>`

In particular, this configuration will never support the following features:
- Debugging. Not an editor's job, use GDB and the like.
- Auto-formatting, because trying to auto-format C++ is a pain!

## Requirements

- Neovim 0.9+, NodeJS **v18**, Python 3 and (optionally) Rust installed
- A terminal with ligature support (**Kitty**, Alacritty, etc.)
  - For kitty, I like to set (after installing Comic Code Ligatures, Font Awesome and Symbols Nerd Font Mono):
    ```
    font_family      ComicCodeLigatures
    symbol_map U+f000-U+f0e2 fontawesome
    symbol_map U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 Symbols Nerd Font Mono
    ```
- An OpenAI-like AI agent in the form of a CLI binary called `chat` 

## List of plugins and important configs

- [keymaps.lua:](lua/user/keymaps.lua) very few keymaps
  - `<space>` is the leader key, which is used to open `which-key` menu in normal mode
  - `s` and `S` in normal mode are used for word hoping
  - `<tab>` and `<S-tab>` in normal mode are used for buffer switching's
- [treesitter.lua:](lua/user/treesitter.lua) syntax highlighting and code folding
  - Sets up a few languages by default; such as C++, Python, Lua and OpenFOAM
- [comments.lua:](lua/user/comments.lua) comment and uncomment lines with `gcc` and `gbc` keymaps
- [mason.lua:](lua/user/mason.lua) sets up a few language servers to support common languges
  - C++/C: with `clangd`, OpenFOAM with `foam_ls`, Lua with `lua_ls` and a few more
  - Type `:Mason` in normal mode for more.
- [lspconfig.lua:](lua/user/lspconfig.lua) configures the LSP servers and sets up keywmaps for some features
  - `gd` and `gD` for go to definition and declaration
  - `K` for hover info
  - You can also get to similar functionality through `<space>l` which uses which-key
- [none-ls.lua:](lua/user/none-ls.lua) an LSP client for formatters and linters
- [lualine.lua:](lua/user/lualine.lua) fast and pretty statusline and winbar
- [indentline.lua:](lua/user/indentline.lua) improves code indentation
- [nvimtree.lua:](lua/user/nvimtree.lua) a file explorer. Simple as that
  - `<space>e` to toggle
- [navbuddy.lua:](lua/user/navbuddy.lua) fast local code navigation
  - `<space>o` to toggle
  - Only enabled on specific filetypes, such as OpenFOAM, C++, Python, Lua files
- [telescope.lua:](lua/user/telescope.lua) fuzzy finder for files, buffers, etc.
  - `<space>f` and `<space>t` take advantage of it
  - In particular `<space>fk` shows you all configured keymaps 
- [cmp.lua:](lua/user/cmp.lua) autocompletion engine
  - `<tab>` to cycle through suggestions, `<cr>` to confirm
  - Autocompletes emojies, buffer text, file paths, snippets, and also shows copilot suggestions as virtual text
  - Even searches with `/`. Type `/@` to search through LSP symbols in code buffers!
  - Completes math functions in Vim's expression register (`<c-r>` in insert mode)
  - Also provides command line completion on `:`
- [copilot.lua:](lua/user/copilot.lua) provides a completion source for `cmp` that uses OpenAI's Copilot
  - Type `:Copilot` in normal mode to login for the first time
  - `<tab>` will pick the suggestion, `<c-l>` will cycle through more suggestions if any
- [autopairs.lua:](lua/user/autopairs.lua) automatically inserts closing brackets, quotes, etc.
- [which-key.lua:](lua/user/which-key.lua) shows you all keymaps available in normal mode
- [harpoon.lua:](lua/user/harpoon.lua) to bookmark your buffers, and come back to them in a blink of an eye
  - `<space>ha` to bookmark a file, `<space>hh` to see bookmark menu
- [gitsigns.lua:](lua/user/gitsigns.lua) shows you git diff in the sign column
- [neogit.lua:](lua/user/neogit.lua) a git client
  - `<space>gg` to open, `<space>g` in general to do git-related stuff, like staging hunks
- [diffview.lua:](lua/user/diffview.lua) a diff viewer for Git diffs
  - `<space>gd` to open
- [projects.lua:](lua/user/projects.lua) a project manager, mostly for detecting root directories
  - `<space>tp` to open the recent projects list
- [colorizer.lua:](lua/user/optional/colorizer.lua) colorizes color codes in CSS, HTML, etc.
- [dial.lua:](lua/user/optional/dial.lua) a plugin for incrementing and decrementing stuff
  - Overhauled `<c-a>` and `<c-x>` to increment and decrement things (numbers, dates, ..., etc)
- [hop.lua:](lua/user/optional/hop.lua) fast word hopping
  - `s` and `S` to hop to words in normal mode
- [fugitive.lua:](lua/user/optional/fugitive.lua) The good old Git wrapper from Vim
  - Most options from `<space>g` use it
  - too good to leave behind
  - But no keymaps are set, intended for command-line use
- [csv.lua:](lua/user/optional/csv.lua) a CSV viewer which colorizes CSV columns
- [dim.lua:](lua/user/optional/dim.lua) dims inactive code sections
  - Setup for proper dimming of OpenFOAM entries
  - `<space>wt` to toggle
- [blame.lua:](lua/user/optional/blame.lua) shows you git blame info in the status line
- [lens.lua:](lua/user/optional/lens.lua) not so annoying code lens
- [waka.lua:](lua/user/optional/waka.lua) a plugin for tracking your coding time
  - It will ask for an [API key](https://wakatime.com/settings/api-key) on installation
- [sg.lua:](lua/user/optional/sg.lua) public code search through [sourcegraph](https://sourcegraph.com)
  - Try `<space>ss` and type some class's name
- [leetcode.lua:](lua/user/optional/leetcode.lua) a plugin for solving LeetCode problems
  - `nvim leetcode.nvim` to open
  - Login by copying a cookie token from your browser. Take a look at [the plugin's docs](https://github.com/kawre/leetcode.nvim)
    for more info.
- [noice.lua:](lua/user/optional/noice.lua) nicer UI.
