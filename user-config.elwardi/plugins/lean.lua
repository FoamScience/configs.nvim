local M = {
    'Julian/lean.nvim',
    event = { 'BufReadPre *.lean', 'BufNewFile *.lean' },
    dependencies = {
        'nvim-lua/plenary.nvim',
    },
}

M.config = function()
    require('lean').setup({ mappings = false })
    -- kill lean split if it's the last thing remaining
    vim.api.nvim_create_autocmd("WinEnter", {
        callback = function()
            local normal_wins = 0
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local config = vim.api.nvim_win_get_config(win)
                if config.relative == "" then
                    normal_wins = normal_wins + 1
                end
            end
            if normal_wins == 1 and vim.bo.filetype == "leaninfo" then
                vim.schedule(function()
                    vim.cmd("q")
                end)
            end
        end,
    })
end

return M
