local M = {
    "vimpostor/vim-tpipeline",
    branch = "master",
    cond = function()
        return vim.env.TMUX ~= nil
    end,
}

M.config = function() end

return M
