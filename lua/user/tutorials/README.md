# Interactive Tutorial System

An interactive, step-by-step tutorial system for learning this configuration features.

## Features

- **Lua-based tutorials**: Easy to create and modify
- **Interactive validation**: Auto-detects when you complete each step; when I'm not lazy to implement the check
- **Initial state setup**: Automatically prepares the environment for each tutorial
- **Floating sidebar UI**: Instructions appear in a persistent sidebar

## Usage

> Tutorials are only available when Neovim starts without opening files
> (e.g., `nvim` not `nvim file`). This prevents tutorial interference when doing regular work.

### Starting a Tutorial

1. Press `<Space>tt` or run `:Tutorials`
2. Select a tutorial from the picker
3. Follow the step-by-step instructions
4. The tutorial auto-advances when you complete each step

### Commands

| Command | Keybinding | Description |
|---------|------------|-------------|
| `:Tutorials` | `<Space>tt` | Open tutorial picker |
| `:TutorialNext` | `<Space>tn` | Go to next step (force advance) |
| `:TutorialPrev` | `<Space>tp` | Go to previous step |
| `:TutorialQuit` | `<Space>tq` | Exit current tutorial |
| `:TutorialRestart` | `<Space>tr` | Restart current tutorial |


## Creating Custom Tutorials

Add a lua file to `lua/user/tutorials/data` folder. you can use existing
ones as a reference.

### Setup Action Types

**File/Buffer Operations:**
- `open_file` - Open file or create scratch buffer
- `open_temp_file` - Create temporary file, with LSP setup among other things
- `set_filetype` - Set buffer filetype

**Window Operations:**
- `split` - Create window splits
- `resize` - Set window dimensions
- `focus_window` - Move cursor to window

**Environment:**
- `command` - Execute vim command (supports `ignore_errors: true` to skip if command fails)
- `lua` - Execute lua code
- `set_option` - Set vim option temporarily

**State Management:**
- `save_layout` - Save window layout for restoration
- `mark_buffers` - Mark buffers for cleanup
- `restore_layout` - Restore saved layout
- `close_all_tutorial_buffers` - Clean up tutorial buffers

### Validation Types

- `filetype` - Check buffer filetype
- `buffer_name` - Check buffer name (supports patterns)
- `window_count` - Count windows (supports operators: `>`, `<`, `>=`, `<=`)
- `buffer_count` - Count buffers
- `cursor_position` - Check cursor line/column
- `command` - Execute command and check output
- `window_position` - Check if at edge (left, right, top, bottom)
- `lua_function` - Custom lua validation function

**Note:** Use `ignore_errors: true` for commands that might not be
available (e.g., lazy-loaded plugins).

## Architecture

```
lua/
├── user/tutorials/
│   ├── init.lua          # Plugin entry point and commands
│   ├── README.md         # This file
│   └── data/
│       └── tutorial1.lua # Tutorial definitions
└── tutorials/            # Utility modules (outside plugin namespace)
    ├── manager.lua       # State management and progression
    ├── ui.lua            # UI with vim.ui.select integration
    └── setup.lua         # Initial state setup/teardown
```

## Tips

1. Tutorials auto-advance when validation succeeds
1. Setup/teardown ensures clean environment for each tutorial
1. Press `<Space>tq` anytime to exit and clean up
1. All setup state (buffers, windows, options) is automatically cleaned up
