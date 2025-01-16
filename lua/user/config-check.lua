-- Function to check if there are remote commits to pull
function check_config_updates()
    local notifier = vim
    local noice_ok, noice = pcall(require, "noice")
    if noice_ok then
        notifier = noice
    else
        notifier = vim
    end
    local success, err = pcall(function()
    local nvim_config_path = vim.fn.stdpath('config')
    vim.fn.chdir(nvim_config_path)

    -- Get the current branch name
    local branch = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
    if not branch then
        vim.notify("Not in a git repository", vim.log.levels.ERROR)
        return
    end
    vim.fn.system("git fetch")
    local commits_ahead = vim.fn.systemlist("git log --oneline " .. branch .. "..origin/" .. branch)

    if #commits_ahead > 0 then
        notifier.notify("There are commits to pull. Run git pull in " .. vim.fn.stdpath('config'), vim.log.levels.WARN)
    end
    end)
    if not success then
        notifier.notify("Couldn't check configuration updates", vim.log.levels.WARN)
    end
end

if vim.g.config_check_for_updates then
    vim.cmd([[autocmd VimEnter * lua check_config_updates()]])
end

vim.api.nvim_create_user_command('CheckConfigurationUpdates', check_config_updates, {})
