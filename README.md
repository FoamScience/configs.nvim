![](https://img.shields.io/badge/supports%20nvim-v0.12%2B-huh?style=for-the-badge&logo=neovim&logoColor=green)

This is my minimal(?), clutter-free, less-than-a-million-keymaps Neovim configuration for day-to-day programming.

> [!TIP]
> Best used with **Kitty** terminal (or Alacritty if you prefer that), running a PowerLine font (or at least,
> a font that has some ligatures support)


> [!IMPORTANT]
> Want to get started? -> Press `<space>` and discover what's possible from there

Here are a few programming languages I usually write in:
- C++/C (and OpenFOAM code)
- Python, Lua as scripting languages
- HTML, CSS, JavaScript/TypeScript for web development
- Markdown for writing READMEs and other documentation, LATEX for academic writing
- GdScript, GLSL for game development
- Obviously, Bash for shell scripting

This configuration intentionally avoids:
- Format-on-Save (too complex and opinionated)
- AI assistants (Copilot, CodeCompanion, Avante - removed for simplicity)
- DAP debugging plugins (removed in favor of simpler debugging workflows)

> [!IMPORTANT]
> Check out the [Screenshots][] for a preview of what this configuration has to offer.

![screenshot](./screenshots/nvim.png)

<!-- mtoc-start:cb9ef56 -->

* [Requirements](#requirements)
* [Set up](#set-up)
* [List of plugins and important configs](#list-of-plugins-and-important-configs)
  * [General Notes](#general-notes)
  * [General](#general)
  * [UI](#ui)
  * [Productivity](#productivity)
  * [Navigation](#navigation)
  * [Language support and LSPs](#language-support-and-lsps)
  * [Git integration](#git-integration)
  * [Miscellaneous](#miscellaneous)
* [Configuration Presets](#configuration-presets)
  * [Setting Your Preset](#setting-your-preset)
  * [SSH Usage Example](#ssh-usage-example)
* [Documentation](#documentation)
* [User Configuration Integration](#user-configuration-integration)
  * [Setup](#setup)
  * [Example User Plugin Spec](#example-user-plugin-spec)
* [Plugin Version Management](#plugin-version-management)
  * [Checking for Updates](#checking-for-updates)
  * [Plugin Update Workflow](#plugin-update-workflow)

<!-- mtoc-end:cb9ef56 -->
## Requirements

Run `:checkhealth config` (or `:ConfigHealth`) to verify your setup, see what's missing and how to install
them; here is a list of what fuels this configuration:

**Required dependencies:**
- [Neovim][] **v0.12.x or newer**, [NodeJS][] **v22** (or newer), preferably installed with [NVM][],
- Python 3 and (optionally) [Rust][]
- The tree-sitter CLI. Install with `npm install -g tree-sitter-cli`, or with `cargo`
- For installing some LSP servers, you will need the `unzip` command
- For Todo-comments and various other searching tasks, you will want [RIPGrep][]
- A terminal with ligature support ([Kitty][], Warp, Alacritty, etc.)
  - For kitty, I like to set (after installing Comic Code Ligatures, Font Awesome and Symbols Nerd Font Mono):
    ```
    font_family      ComicCodeLigatures
    symbol_map U+f000-U+f0e2 fontawesome
    symbol_map U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 Symbols Nerd Font Mono
    ```

**Optional:**
- [ImageMagick][] for in-terminal image display, if your terminal supports it
- `latex2text` command if you want to render Tex equations in Markdown
- Also [mermaid-cli][] for mermaid charts in markdown files
  - Note that on Ubuntu 23+ this requires changes to apparmor policies on retricting user namespaces;
    if you don't write mermaid charts often, don't bother with this. Otherwise, you'll have to do the policy changes manually

## Set up

1. Then, applying this configuration is as easy as:
```sh
# Backup old configs and clone the new ones
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/FoamScience/configs.nvim ~/.config/nvim
# also, update with git pull
```
1. Run `:checkhealth config` to see what dependencies you are missing.
   [this docker file](/dockerImages/config.dockerfile) shows how to install
   most of the required ones on latest Ubuntu LTS release.

From there, the `:ConfigNews` command helps you keep your configuration up-to-date with this repo by checking for new commits and displaying a changelog.

Or you can give it a try in a Docker container:
```sh
cd dockerImages
docker build -t nvim-config:latest -f config.dockerfile . 
docker run -it --rm nvim-config:latest bash
(container)> USER=me nvim
```

## List of plugins and important configs

### General Notes

- The canonical way to move between open buffers is `<tab>` and `<S-tab>` in normal mode.
- The canonical way to move on the visible screen portion is by pressing `s` and `S` in normal mode.
- The canonical way to move between windows and splits is `<C-w><C-w>`; too fundamental to change.
- Typically, you'll want to set Tmux to move between panes with `<C-s><arrows>`.
- You can bookmark files (Press `,`) within each project for faster workflow. This was preferred over session management.
- You can see registers content by pressing `"`, and marks positions by pressing the back-tick '`'
- `<space>` is the **leader key**, which is used to open `which-key` menu in normal mode
- `<leader>fk` lists all available key bindings and `<leader>fC` lists commands.
- `<leader>fP` will take you to individual plugin configuration!
- `<leader>kk` brings up a sticky-notes sidebar. it persists; and it's project-specific!
  - you can create mutiple notes per projects and notes content is in Markdown

### General

- [whichkey.lua:](lua/user/whichkey.lua) shows all available keymaps
  - Press `<leader>` to check available keymaps
  - Shows Vim keymaps on `` ` `` (marks), `"` (registers), `z` (folds and spelling), `g` (operators)
  and `<c-w>` (window navigation)
- [snacks.lua:](lua/user/snacks.lua) fuzzy finder via snacks.picker for files, buffers, etc.
  - `<leader>f` to access fuzzy finding features
  - `<leader>fk` shows all configured keymaps
  - `<leader>fg` opens file from its Git history without checking out earlier commits
  - `<leader>fu` browses the Undo tree with diffs
  - `<leader>fP` opens Plugin configuration files
  - Note: Excluded from SSH preset due to performance considerations
- [project.lua:](lua/user/project.lua) a project manager, mostly for detecting root directories
  - `<leader>fp` to open recent projects list
- [dial.lua:](lua/user/optional/dial.lua) a plugin for incrementing and decrementing stuff
  - Overhauled `<c-a>` and `<c-x>` to increment and decrement things (numbers, dates, ..., etc)
- [colorscheme.lua](lua/user/colorscheme.lua) is where the color scheme is set
  - Press `<leader>fc` to see a live demo of all available color schemes
  - By default, we are using [Catppuccin-Mocha](https://catppuccin.com/)
- [undo.lua](lua/user/undo.lua) is an Undo tree visualizer, with diff views. `<leader>eu` to toggle.

### UI

- [snacks.lua](lua/user/snacks.lua) a collection of UI niceties from folke (includes fuzzy finder)
- [nvimtree.lua:](lua/user/nvimtree.lua) a file explorer
  - `<leader>ee` to toggle
- [oil.lua:](lua/user/oil.lua) file explorer as an editable buffer, replaces netrw
  - `-` opens the parent directory
- [mini-statusline.lua](./lua/user/mini-statusline.lua) fast and minimal statusline with enhanced LSP status
- [tpipeline.lua](lua/user/optional/tpipeline.lua) unified statusline for Neovim and Tmux
  - Displays single statusline across both Neovim and Tmux for seamless integration
  - Only loaded in "full" preset
- [incline.lua](lua/user/incline.lua) floating buffer names at top-right corners of windows
- [noice.lua:](lua/user/noice.lua) nicer UI. Not relevant for users
- [fidget.lua:](lua/user/fidget.lua) LSP progress notifications in the corner
- [colorizer.lua:](lua/user/optional/colorizer.lua) colorizes color codes in CSS, HTML, etc.
- [cinnamon.lua:](lua/user/optional/cinnamon.lua) optional scrolling cursor animations.
- [render-markdown.lua:](lua/user/render-markdown.lua) prettifying Markdown document editing.
  - With support for Latex equation rendering
- [guess-indent.lua](lua/user/guess-indent.lua) to guess indentation style (tabs/spaces)
  for current file and setting global options accordingly.
  - Should be automatic, but `:GuessIndent` helps
- [image.lua:](lua/user/image.lua) inline/floating image rendering via image.nvim, replaces `snacks.image`
  - Needs `imagemagick` (`magick`/`convert`) on PATH, and `kitty` or `wezterm` with the kitty graphics protocol enabled
  - `<leader>vi` to render the image under the cursor

### Productivity

- [todo-comments.lua:](lua/user/todocomments.lua) highlights `@todo:`, `@body:`, `@warn:`, etc. in comments
  - `:TodoTelescope` command opens a fuzzy finder for all such comments in the current buffer
  - Use [todo-issue Github action](https://github.com/DerJuulsn/todo-issue) to convert your committed
    Todos to Github issues.
- [atlassian.lua:](lua/user/atlassian.lua) conflira.nvim, a thin Jira and Confluence client (merges the former separate jira/confluence plugins)
  - Loaded only if `JIRA_API_TOKEN` or `CONFLUENCE_API_TOKEN` is set
  - Have to set `JIRA_API_TOKEN`/`CONFLUENCE_API_TOKEN`, `JIRA_URL`/`CONFLUENCE_URL` and `JIRA_EMAIL`/`CONFLUENCE_EMAIL`
  - `<leader>j` for Jira, `<leader>c` for Confluence
- [markdown-toc.lua:](lua/user/markdown-toc.lua) auto-generates and updates a Markdown table of contents
  - Updates on save for Markdown files
- [img-clip.lua:](lua/user/img-clip.lua) pastes clipboard images into the buffer (e.g. Markdown image links)
  - Excluded over SSH
- [neotest.lua:](lua/user/neotest.lua) test runner UI, with neotest-python (pytest) as the Python adapter
  - `<leader>t` for test commands (run nearest/file/directory/last, summary, output, watch)

### Navigation

- [flash.lua:](lua/user/flash.lua) fast word hopping
  - `s` (or `gs`) to hop to words in normal mode
  - `S` (or `gS`) to hop using tree-sitter syntax tree in normal mode
  - `r` in operator mode to do operations between flash hops
  - `R` in operator mode to do operations between flash tree-sitter searches
  - `<ctrl-s>` to toggle flash in regular search mode
  - `<leader>v` for incremental treesitter selection (next: `<leader>v`, prev: `<BS>`)
- [outline.lua:](lua/user/outline.lua) fast local code navigation
  - `<leader>nn` to toggle
  - `?` to see keymaps for the outline window
- [trouble.lua:](lua/user/trouble.lua) pretty list for diagnostics, symbols, LSP refs and the quickfix/location list
  - `<leader>x` for Trouble commands
- [qf.lua:](lua/user/qf.lua) nvim-bqf, a better preview and UI for the quickfix window

### Language support and LSPs

- [treesitter/init.lua:](lua/user/treesitter/init.lua) syntax highlighting and code folding, via a thin custom grammar installer (replaces the archived nvim-treesitter plugin)
  - Sets up a few languages by default; such as C++, Python, Lua and OpenFOAM
  - Auto-installs tree-sitter grammars for languages the first time they are encountered
  - with `xonsh` support through the [xonsh-lsp](https://github.com/FoamScience/xonsh-language-server)
- [mason.lua:](lua/user/mason.lua) sets up a few language servers to support common languages
  - C++/C: with `clangd`, OpenFOAM with `foam_ls`, Lua with `lua_ls` and a few more
    - `clangd` is not managed through Mason on ARM machines, run `apt install clangd` instead
  - Python: `pyright` or `pylsp`, with support for ParaView Python (pvpython) environments
  - Type `:Mason` in normal mode for more.
- [lspconfig.lua:](lua/user/lspconfig.lua) configures the LSP servers and sets up keymaps for some features
  - `gd` and `gD` for go to definition and declaration
  - `K` for hover info
  - Enhanced keybindings for type hierarchy, call graphs, and symbol navigation
  - You can also get to similar functionality through `<leader>l` which uses which-key
  - Also pulls in clangd_extensions.nvim (AST view, memory usage) for C++ and lazydev.nvim for Lua/`vim.*` completion
- [cmp.lua:](lua/user/cmp.lua) autocompletion engine using blink.cmp (faster than nvim-cmp)
  - `<tab>` to cycle through suggestions, `<cr>` to confirm
  - Autocompletes file paths, snippets, and LSP-related things
  - Includes Unicode character completion provider for special characters
  - Buffer completion is left to vim's native: `<c-x>-n` menu
  - Also provides command line completion on `:`
- [conform.lua:](lua/user/conform.lua) formatter orchestration (stylua, ruff_format, clang-format, latexindent, typstyle, shfmt, ...)
  - `<leader>lf` to format, falling back to the LSP formatter if none matches
  - Format-on-save; `:FormatDisable[!]` / `:FormatEnable` to toggle
- [cmake-tools.lua:](lua/user/cmake-tools.lua) CMake configure/build/run from inside Neovim
  - `<leader>m` for CMake commands (generate, build, run, select target/type, clean)
  - Soft-links `compile_commands.json` to the project root, which `clangd` picks up
- [refactoring.lua:](lua/user/refactoring.lua) language-aware extract/inline refactors (C++, Python, Lua, ...)
  - `<leader>r` for refactor commands (extract function/variable/block, inline variable)
- [lean.lua:](user-config.elwardi/plugins/lean.lua) Lean 4 theorem prover support via lean.nvim
  - Loads for `*.lean` files
- [typst.lua:](lua/user/optional/typst.lua) live-preview for Typst documents via typst-preview.nvim
  - Opens the preview in the browser for `typst` files
- [navic.lua:](lua/user/navic.lua) shows code structure at the cursor in the winbar
- [remote-nvim.lua:](lua/user/remote-nvim.lua) connect to remote Neovim instances over SSH
  - Commands: `:RemoteStart`, `:RemoteStop`, `:RemoteInfo`
  - Uses telescope for UI (only plugin requiring telescope in this config)

### Git integration

- [gitsigns.lua:](lua/user/gitsigns.lua) shows git diff in the sign column
- [diffview.lua:](lua/user/diffview.lua) a diff viewer for Git diffs
  - `<leader>gd` to open, or `:DiffviewOpen` in normal mode
- [gitconflicts.lua:](lua/user/gitconflicts.lua) git conflict resolution UI via diffconflicts.nvim
  - `<leader>gt` to open, or `:DiffConflicts` in normal mode
- [butlr.lua:](user-config.elwardi/plugins/butlr.lua) GitButler hunk navigation and actions via butlr.nvim
  - Only enabled inside a GitButler-managed repo (needs the `but` CLI)
  - `<leader>b` for Butler commands (navigate hunks, rub/assign, absorb, discard, undo)

### Miscellaneous

- [autopairs.lua:](lua/user/autopairs.lua) automatically inserts closing brackets, quotes, etc.
- [csv.lua:](lua/user/optional/csv.lua) a CSV viewer/editor using csvview.nvim.
  - `<leader>cv` toggles the aligned CSV display
- [haunt.lua:](lua/user/optional/haunt.lua) Line notes that do not affect the code source.
- [cloak.lua:](lua/user/optional/cloack.lua) Hiding environment variables.
  - `:CloackDisable` to see the variables' values.
- [wrapped.lua:](user-config.elwardi/plugins/wrapped.lua) a GitHub-Wrapped-style yearly recap via wrapped.nvim (UI built on nvzone/volt)
  - `:WrappedNvim` to open

## Configuration Presets

This configuration supports multiple presets to adapt to different usage scenarios. Currently available presets:

- **full** (default): All plugins enabled, full feature set
- **ssh**: Minimal preset optimized for remote SSH connections
  - Excludes plugins that don't work well over SSH, mostly for adding latency overhead

### Setting Your Preset

There are three ways to select a preset (in order of priority):

1. **Local preset file** (recommended for per-machine configuration):
   ```bash
   # Copy the example file and edit it
   cp ~/.config/nvim/preset.lua.example ~/.config/nvim/preset.lua
   # Edit preset.lua and change the return value to "ssh" or "full"
   ```

2. **Environment variable** (useful for one-time overrides):
   ```bash
   NVIM_PRESET=ssh nvim
   ```

3. **Default**: Falls back to "full" if neither of the above is set

### SSH Usage Example

For remote editing over SSH, use the ssh preset to improve performance:

```bash
# On your remote machine, create a preset file
echo 'return "ssh"' > ~/.config/nvim/preset.lua

# Or use environment variable
export NVIM_PRESET=ssh
nvim myfile.cpp
```

## Documentation

A few tutorials can be accessed by `<leader>tt` when `nvim` command had no files
passed in. These are not meant to teach people basic Vim skills but
rather explain my current approach to editing efficiency.

Even though the tutorials act on Lua files, they hold on any other filetype.

Occasionally, you'd have to `:TutorialNext` to continue a tutorial, either becausse
I was too lazy to implement proper step validation or implementing it would not
have provided a good experience.


## User Configuration Integration

You can seamlessly extend this configuration by using a separate user configuration repository.

### Setup

1. Create your own configuration repository with this structure:
   ```
   my-nvim-config/
   ├── init.lua              # Optional: runs before lazy.nvim loads
   └── plugins/              # Optional: custom plugin specs
       ├── my-plugin.lua
       └── another.lua
   ```

2. Symlink your repository to the user-config directory:
   ```bash
   ln -s /path/to/my-nvim-config ~/.config/nvim/user-config
   ```
   Or you could just do to get my configuration (may super niche stuff and mostly
   experimental):
   ```bash
   ln -s user-config.elwardi user-config
   ```

3. Your configuration will be loaded automatically:
   - `init.lua` is executed before lazy.nvim initialization
   - All files in `plugins/` are loaded as plugin specs

### Example User Plugin Spec

Create `~/.config/nvim/user-config/plugins/my-theme.lua`:

```lua
return {
    "username/my-colorscheme",
    config = function()
        vim.cmd("colorscheme my-colorscheme")
    end
}
```

This approach allows you to:
- Keep your customizations in a separate git repository
- Pull updates from this main config without conflicts
- Share settings across multiple machines with different needs

## Plugin Version Management

All plugins are locked to specific versions using [Lazy.nvim][]'s lockfile feature. This ensures:
- Consistent plugin versions across all installations
- Protection against breaking changes from plugin updates
- Reproducible development environment

### Checking for Updates

Use the `:ConfigNews` command to check for configuration updates:

```vim
:ConfigNews
```

This will:
- Fetch the latest changes from the remote repository
- Show how many commits you're behind
- Display a changelog of recent commits
- Provide instructions for updating

### Plugin Update Workflow

The recommended workflow for keeping plugins up-to-date:

1. Check for config updates: `:ConfigNews`
2. Pull config updates: `git pull` in `~/.config/nvim`
3. Review changes in `lazy-lock.json` if any
4. Restart nvim to apply changes

Alternatively you could just run `:Lazy update`; although this will diverge from this repo's plugin versions.

[Screenshots]: /screenshots/README.md "Screenshots"
[Neovim]: https://github.com/neovim/neovim/releases "Neovim"
[NVM]: https://github.com/nvm-sh/nvm "NVM"
[NodeJS]: https://nodejs.org "NodeJS"
[RIPGrep]: https://github.com/BurntSushi/ripgrep "RIPGrep"
[Kitty]: https://sw.kovidgoyal.net/kitty/binary/ "Kitty"
[Rust]: https://www.rust-lang.org/tools/install "Rust"
[TGPT]: https://github.com/aandrew-me/tgpt "TGPT"
[SourceGraph]: https://sourcegraph.com "SourceGraph"
[Neorg]: https://github.com/nvim-neorg/neorg "Neorg"
[ImageMagick]: https://imagemagick.org/index.php "ImageMagick"
[mermaid-cli]: https://github.com/mermaid-js/mermaid-cli "Mermaid-cli"
[Lazy.nvim]: https://github.com/folke/lazy.nvim "Lazy.nvim"
