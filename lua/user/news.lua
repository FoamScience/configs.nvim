-- ConfigNews: Check for configuration updates

local M = {}

function M.setup()
    vim.api.nvim_create_user_command("ConfigNews", function()
        local config_dir = vim.fn.stdpath("config")
        local is_git = vim.fn.isdirectory(config_dir .. "/.git") == 1
        if not is_git then
            vim.notify("Config directory is not a git repository", vim.log.levels.WARN)
            return
        end
        local has_fidget, progress = pcall(require, "fidget.progress")
        local handle
        if has_fidget then
            handle = progress.handle.create({
                title = "Config News",
                message = "Fetching updates...",
            })
        else
            vim.notify("Fetching latest config changes...", vim.log.levels.INFO)
        end
        local fetch_result = vim.fn.system("cd " .. config_dir .. " && git fetch origin 2>&1")
        if vim.v.shell_error ~= 0 then
            if handle then handle:finish() end
            vim.notify("Failed to fetch from remote:\n" .. fetch_result, vim.log.levels.ERROR)
            return
        end
        local default_branch = vim.fn.system("cd " .. config_dir .. " && git rev-parse --abbrev-ref origin/HEAD 2>&1 | cut -d'/' -f2"):gsub("%s+", "")
        if vim.v.shell_error ~= 0 then
            default_branch = "master"
        end
        if handle then handle:report({ message = "Checking for updates...", percentage = 50 }) end

        local commits_behind = vim.fn.system("cd " .. config_dir .. " && git rev-list HEAD..origin/" .. default_branch .. " --count 2>&1"):gsub("%s+", "")
        if vim.v.shell_error ~= 0 then
            if handle then handle:finish() end
            vim.notify("Failed to check for updates", vim.log.levels.ERROR)
            return
        end
        local behind_count = tonumber(commits_behind) or 0
        if behind_count == 0 then
            if handle then handle:finish("Up to date") end
            vim.notify("Config is up to date!", vim.log.levels.INFO)
            return
        end

        if handle then handle:finish("Found updates") end
        local log_cmd = string.format(
            "cd %s && git log HEAD..origin/%s --oneline --decorate --color=never",
            config_dir,
            default_branch
        )
        local log_output = vim.fn.system(log_cmd)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = buf})
        vim.api.nvim_set_option_value("filetype", "git", {buf = buf})

        local header = {
            "Configuration Updates Available",
            string.format("You are %d commit%s behind origin/%s", behind_count, behind_count > 1 and "s" or "", default_branch),
            "",
            "Recent commits:",
            "───────────────────────────────────────────────────────────",
            "",
        }

        local lines = vim.split(log_output, "\n")
        local all_lines = {}
        vim.list_extend(all_lines, header)
        vim.list_extend(all_lines, lines)
        table.insert(all_lines, "")
        table.insert(all_lines, "───────────────────────────────────────────────────────────")
        table.insert(all_lines, "To update: cd " .. config_dir .. " && git pull")

        vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)
        vim.api.nvim_set_option_value("modifiable", false, {buf = buf})

        -- Open in a floating window
        local width = math.min(100, vim.o.columns - 4)
        local height = math.min(30, vim.o.lines - 4)
        local row = math.floor((vim.o.lines - height) / 2)
        local col = math.floor((vim.o.columns - width) / 2)

        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = row,
            col = col,
            style = "minimal",
            border = "rounded",
            title = " Config News ",
            title_pos = "center",
        })

        vim.api.nvim_set_option_value("wrap", false, {win = win})
        vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
    end, {
        desc = "Check for config updates and display changelog",
    })
end

-- Auto-setup when required
M.setup()

return M
