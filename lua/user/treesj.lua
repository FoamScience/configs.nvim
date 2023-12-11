local M = {
	"Wansmer/treesj",
	event = "VeryLazy",
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
}

function M.config()
    require('treesj').setup({
        use_default_keymaps = false,
        max_join_length = 120,
    })
end

return M
