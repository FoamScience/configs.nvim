-- Health check for the whole configuration
-- Run with :checkhealth config

local M = {}
local health = vim.health

-- Track missing dependencies for install summary
local missing_required = {}
local missing_optional = {}

-- Helper to check executable availability
local function check_executable(cmd)
    return vim.fn.executable(cmd) == 1
end

-- Helper to get command output
local function get_cmd_output(cmd)
    local handle = io.popen(cmd .. " 2>/dev/null")
    if not handle then
        return nil
    end
    local result = handle:read("*a")
    handle:close()
    return result and result:gsub("%s+$", "") or nil
end

-- Detect platform
local function get_platform()
    local uname = vim.loop.os_uname()
    if uname.sysname == "Darwin" then
        return "macos"
    elseif uname.sysname == "Linux" then
        -- Check for common distros
        if vim.fn.executable("apt") == 1 then
            return "debian"
        elseif vim.fn.executable("dnf") == 1 then
            return "fedora"
        elseif vim.fn.executable("pacman") == 1 then
            return "arch"
        end
        return "linux"
    end
    return "unknown"
end

-- Get install command for a package
local function get_install_cmd(pkg_name, brew_name, apt_name, dnf_name, pacman_name)
    local platform = get_platform()
    brew_name = brew_name or pkg_name
    apt_name = apt_name or pkg_name
    dnf_name = dnf_name or pkg_name
    pacman_name = pacman_name or pkg_name

    if platform == "macos" then
        return "brew install " .. brew_name
    elseif platform == "debian" then
        return "sudo apt install " .. apt_name
    elseif platform == "fedora" then
        return "sudo dnf install " .. dnf_name
    elseif platform == "arch" then
        return "sudo pacman -S " .. pacman_name
    else
        return "brew install " .. brew_name .. " (or use your package manager)"
    end
end

-- Check Neovim version
local function check_neovim()
    health.start("Neovim")
    health.info("Used for: Core editor runtime, Lua API, LSP client, treesitter integration")

    local version = vim.version()
    local version_str = string.format("%d.%d.%d", version.major, version.minor, version.patch)

    -- Require v0.11.4 or newer
    if version.major > 0 or (version.major == 0 and version.minor >= 11 and version.patch >= 4) then
        health.ok("Neovim " .. version_str .. " (v0.11.4+ required)")
    elseif version.major == 0 and version.minor == 11 then
        health.warn("Neovim " .. version_str .. " (v0.11.4+ recommended)", {
            "Some features may not work correctly",
            "Update: https://github.com/neovim/neovim/releases",
        })
    else
        health.error("Neovim " .. version_str .. " is too old", {
            "This configuration requires Neovim v0.11.4 or newer",
            "Download from: https://github.com/neovim/neovim/releases",
        })
        table.insert(missing_required,
            { name = "neovim", install = get_install_cmd("neovim", "neovim", "neovim", "neovim", "neovim") })
    end
end

-- Check NodeJS
local function check_nodejs()
    health.start("NodeJS")
    health.info("Used for: Mason LSP server installations, tree-sitter-cli, mermaid-cli")

    if not check_executable("node") then
        health.error("NodeJS not found", {
            "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && nvm install 22",
        })
        table.insert(missing_required, {
            name = "nodejs",
            install = "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash && nvm install 22",
        })
        return
    end

    local version_output = get_cmd_output("node --version")
    if version_output then
        local major = tonumber(version_output:match("v(%d+)"))
        if major and major >= 22 then
            health.ok("NodeJS " .. version_output .. " (v22+ required)")
        elseif major and major >= 18 then
            health.warn("NodeJS " .. version_output .. " (v22+ recommended)", {
                "nvm install 22 && nvm use 22",
            })
        else
            health.error("NodeJS " .. version_output .. " is too old", {
                "nvm install 22 && nvm use 22",
            })
        end
    else
        health.warn("Could not determine NodeJS version")
    end

    -- Check npm
    if check_executable("npm") then
        health.ok("npm is available")
    else
        health.warn("npm not found (usually installed with NodeJS)")
    end
end

-- Check Python
local function check_python()
    health.start("Python")
    health.info("Used for: pyright/pylsp LSP servers, UV environment detection, latex2text")

    local python_cmd = nil
    if check_executable("python3") then
        python_cmd = "python3"
    elseif check_executable("python") then
        python_cmd = "python"
    end

    if not python_cmd then
        health.error("Python 3 not found", {
            "Install: apt install python3 (Ubuntu/Debian)",
            "Or: brew install python (macOS)",
        })
        return
    end

    local version_output = get_cmd_output(python_cmd .. " --version")
    if version_output then
        local major = tonumber(version_output:match("Python (%d+)"))
        if major and major >= 3 then
            health.ok(version_output)
        else
            health.error(version_output .. " - Python 3 required", {
                "This configuration requires Python 3",
            })
        end
    else
        health.ok(python_cmd .. " found")
    end
end

-- Check tree-sitter CLI
local function check_treesitter_cli()
    health.start("Tree-sitter CLI")
    health.info("Used for: Compiling language grammars (foam, cpp, python, lua, rust, markdown, etc.)")

    if check_executable("tree-sitter") then
        local version = get_cmd_output("tree-sitter --version")
        health.ok("tree-sitter CLI " .. (version and "(" .. version .. ")" or "found"))
    else
        health.error("tree-sitter CLI not found", {
            "npm install -g tree-sitter-cli",
        })
        table.insert(missing_required, {
            name = "tree-sitter-cli",
            install = "npm install -g tree-sitter-cli",
        })
    end
end

-- Check unzip
local function check_unzip()
    health.start("Unzip")
    health.info("Used for: Mason LSP server extraction, compressed file handling")

    if check_executable("unzip") then
        health.ok("unzip is available")
    else
        health.error("unzip not found", {
            "Install: apt install unzip (Ubuntu/Debian)",
            "Or: brew install unzip (macOS)",
        })
    end
end

-- Check ripgrep
local function check_ripgrep()
    health.start("RipGrep")
    health.info("A faster grep used for: todo-comments.nvim, snacks.picker live grep, project-wide search")

    if check_executable("rg") then
        local version = get_cmd_output("rg --version")
        local version_line = version and version:match("^[^\n]+") or nil
        health.ok(version_line or "ripgrep found")
    else
        local install_cmd = get_install_cmd("ripgrep", "ripgrep", "ripgrep", "ripgrep", "ripgrep")
        health.error("ripgrep (rg) not found", { install_cmd })
        table.insert(missing_required, {
            name = "ripgrep",
            install = install_cmd,
        })
    end
end

-- Check terminal
local function check_terminal()
    health.start("Terminal")
    health.info("Used for: UI rendering, image display (kitty), ligature support, true colors")

    local term = vim.env.TERM or ""
    local term_program = vim.env.TERM_PROGRAM or ""
    local kitty_window_id = vim.env.KITTY_WINDOW_ID

    if kitty_window_id then
        health.ok("Running in Kitty terminal (recommended, supports images)")
    elseif term_program:lower():match("alacritty") or term:lower():match("alacritty") then
        health.ok("Running in Alacritty terminal")
    elseif term_program:lower():match("warp") then
        health.ok("Running in Warp terminal")
    elseif term_program:lower():match("iterm") then
        health.ok("Running in iTerm2")
    elseif term_program:lower():match("wezterm") then
        health.ok("Running in WezTerm (supports images)")
    elseif term:match("256color") or term:match("kitty") then
        health.ok("Terminal: " .. term .. " (256 color support detected)")
    else
        health.warn("Unknown terminal: " .. (term_program ~= "" and term_program or term), {
            "Recommended: Kitty, Alacritty, Warp, or any terminal with ligature support",
        })
    end

    health.info("Tip: Use a Nerd Font (e.g., Symbols Nerd Font Mono) for icons")
end

-- Check Rust
local function check_rust()
    health.start("Rust")
    health.info("Used for: Rust development, treesitter rust parser, cargo install tools")

    if check_executable("rustc") then
        local version = get_cmd_output("rustc --version")
        health.ok(version or "Rust found")
        if check_executable("cargo") then
            health.ok("cargo is available")
        end
    else
        health.error("Rust not found", {
            "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
        })
        table.insert(missing_required, {
            name = "rust",
            install = "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
        })
    end
end

-- Check optional: ImageMagick
local function check_imagemagick()
    health.start("ImageMagick (optional)")
    health.info("Used for: snacks.image in-terminal image display and conversion")

    local has_convert = check_executable("convert")
    local has_magick = check_executable("magick")

    if has_convert or has_magick then
        local version = get_cmd_output((has_magick and "magick" or "convert") .. " --version")
        local version_line = version and version:match("^[^\n]+") or nil
        health.ok(version_line or "ImageMagick found")
    else
        health.info("ImageMagick not installed", {
            "Install: apt install imagemagick (Ubuntu/Debian)",
            "Or: brew install imagemagick (macOS)",
        })
    end
end

-- Check optional: latex2text
local function check_latex2text()
    health.start("latex2text (optional)")
    health.info("Used for: render-markdown.nvim LaTeX equation rendering in Markdown")

    if check_executable("latex2text") then
        health.ok("latex2text is available")
    else
        if check_executable("pandoc") then
            health.info("latex2text not found, but pandoc is available as alternative")
        else
            health.info("latex2text not installed (part of pylatexenc)", {
                "Install: uv tool install pylatexenc",
            })
        end
    end
end

-- Check optional: mermaid-cli
local function check_mermaid()
    health.start("Mermaid CLI (optional)")
    health.info("Used for: render-markdown.nvim Mermaid diagram rendering")

    if check_executable("mmdc") then
        local version = get_cmd_output("mmdc --version")
        health.ok("mermaid-cli " .. (version or "found"))
    else
        health.info("mermaid-cli (mmdc) not installed", {
            "Install: npm install -g @mermaid-js/mermaid-cli",
            "Note: Ubuntu 23+ may require AppArmor policy changes",
        })
    end
end

-- Check git
local function check_git()
    health.start("Git")
    health.info("Used for: lazy.nvim plugin management, gitsigns.nvim, diffview.nvim, ConfigNews")

    if check_executable("git") then
        local version = get_cmd_output("git --version")
        health.ok(version or "git found")
    else
        health.error("git not found", {
            "Install: apt install git (Ubuntu/Debian)",
            "Or: brew install git (macOS)",
        })
    end
end

-- Check configuration preset
local function check_preset()
    health.start("Configuration")

    -- Check current preset
    local preset = vim.g.active_preset or "full"
    health.info("Active preset: " .. preset)

    if preset == "ssh" then
        health.info("SSH preset active - some plugins disabled for better latency")
    end

    -- Check user-config
    local user_config_dir = vim.fn.stdpath("config") .. "/user-config"
    local user_config_stat = vim.loop.fs_stat(user_config_dir)
    if user_config_stat and user_config_stat.type == "directory" then
        health.ok("User configuration found at: " .. user_config_dir)
    else
        health.info("No user-config directory (optional)")
    end
end

-- Check for configuration updates (ConfigNews integration)
local function check_config_updates()
    health.start("Configuration Updates")

    local config_dir = vim.fn.stdpath("config")

    -- Check if config directory is a git repo
    local is_git = vim.fn.isdirectory(config_dir .. "/.git") == 1
    if not is_git then
        health.info("Config directory is not a git repository")
        health.info("Updates checking is only available for git-managed configs")
        return
    end

    health.ok("Config is a git repository")

    -- Try to fetch from remote (with timeout)
    local fetch_result = get_cmd_output("cd " .. config_dir .. " && git fetch origin 2>&1")
    if not fetch_result then
        health.warn("Could not fetch from remote", {
            "Check your network connection",
            "Run :ConfigNews manually for detailed info",
        })
        return
    end

    -- Get default branch
    local default_branch = get_cmd_output("cd " ..
        config_dir .. " && git rev-parse --abbrev-ref origin/HEAD 2>/dev/null | cut -d'/' -f2")
    if not default_branch or default_branch == "" then
        default_branch = "master"
    end

    -- Check commits behind
    local commits_behind = get_cmd_output("cd " ..
        config_dir .. " && git rev-list HEAD..origin/" .. default_branch .. " --count 2>/dev/null")
    local behind_count = tonumber(commits_behind) or 0

    if behind_count == 0 then
        health.ok("Configuration is up to date with origin/" .. default_branch)
    elseif behind_count == 1 then
        health.warn("Configuration is 1 commit behind origin/" .. default_branch, {
            "Run :ConfigNews to see what's new",
            "Update with: cd " .. config_dir .. " && git pull",
        })
    else
        health.warn("Configuration is " .. behind_count .. " commits behind origin/" .. default_branch, {
            "Run :ConfigNews to see what's new",
            "Update with: cd " .. config_dir .. " && git pull",
        })
    end

    -- Check for local modifications
    local status = get_cmd_output("cd " .. config_dir .. " && git status --porcelain 2>/dev/null")
    if status and status ~= "" then
        local lines = vim.split(status, "\n")
        local modified_count = #vim.tbl_filter(function(l) return l ~= "" end, lines)
        health.info(modified_count .. " local modification(s) detected")
    end
end

-- Show install summary for missing dependencies
local function check_install_summary()
    if #missing_required == 0 and #missing_optional == 0 then
        return
    end

    health.start("Install Summary")

    if #missing_required > 0 then
        health.warn("Missing required dependencies:")
        for _, dep in ipairs(missing_required) do
            health.info("  " .. dep.name .. ": " .. dep.install)
        end
    end

    if #missing_optional > 0 then
        health.info("Missing optional dependencies:")
        for _, dep in ipairs(missing_optional) do
            health.info("  " .. dep.name .. ": " .. dep.install)
        end
    end
end

function M.check()
    -- Reset tracking
    missing_required = {}
    missing_optional = {}

    -- Required dependencies
    check_neovim()
    check_nodejs()
    check_python()
    check_treesitter_cli()
    check_unzip()
    check_ripgrep()
    check_rust()
    check_git()
    check_terminal()

    -- Optional dependencies
    check_imagemagick()
    check_latex2text()
    check_mermaid()

    -- Configuration status
    check_preset()
    check_config_updates()

    -- Install summary at the end
    check_install_summary()
end

return M
