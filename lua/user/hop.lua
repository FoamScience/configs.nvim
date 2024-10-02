local M = {
    "hadronized/hop.nvim",
    cmd = { "HopWord", "HopLine", "HopeChar1", "HopChar2", "HopAnywhere" },
    event = "VeryLazy",
}

function M.config()
    require 'hop'.setup {
        keys = 'etovxqpdygfblzhckisuran',
    }
    -- hopping
    local keymap = vim.keymap.set
    local opts = { noremap = true, silent = true }
    hop_ok, _ = pcall(require, "hop")
    if hop_ok then
        keymap("n", "s", "<cmd>HopWord<cr>", opts)
        keymap("n", "S", "<cmd>HopChar2<cr>", opts)
    end
end

return M
