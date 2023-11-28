local M = {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPost", "BufNewFile" },
	build = ":TSUpdate",
	dependencies = {
		{
			"nvim-treesitter/nvim-treesitter-textobjects",
			event = "VeryLazy",
		},
		--{
		--	"JoosepAlviste/nvim-ts-context-commentstring",
		--	event = "VeryLazy",
		--},
		{
			"windwp/nvim-ts-autotag",
			event = "VeryLazy",
		},
		{
			"windwp/nvim-autopairs",
			event = "InsertEnter",
		},
        {
            "nvim-treesitter/playground",
            cmd = "TSPlaygroundToggle",
        },
	},
}
function M.config()
	require("nvim-treesitter.configs").setup {
		ensure_installed = {
				"lua", "vim",
				"markdown", "markdown_inline",
				"bash",
				"python",
				"foam", "cpp", "c",
				"rust",
				"glsl"
		},
		ignore_install = { "" },
		sync_install = false,
		highlight = {
			enable = true,
			disable = { "markdown" },
			additional_vim_regex_highlighting = false,
		},

		indent = { enable = true },

		matchup = {
			enable = { "astro" },
			disable = { "lua" },
		},

		autotag = { enable = true },

		--context_commentstring = {
		--	enable = true,
		--	enable_autocmd = false,
		--},

		autopairs = { enable = true },

		textobjects = {
			select = {
				enable = true,
				lookahead = true,
				keymaps = {
					["af"] = "@function.outer",
					["if"] = "@function.inner",
					["at"] = "@class.outer",
					["it"] = "@class.inner",
					["ac"] = "@call.outer",
					["ic"] = "@call.inner",
					["aa"] = "@parameter.outer",
					["ia"] = "@parameter.inner",
					["al"] = "@loop.outer",
					["il"] = "@loop.inner",
					["ai"] = "@conditional.outer",
					["ii"] = "@conditional.inner",
					["a/"] = "@comment.outer",
					["i/"] = "@comment.inner",
					["ab"] = "@block.outer",
					["ib"] = "@block.inner",
					["as"] = "@statement.outer",
					["is"] = "@scopename.inner",
					["aA"] = "@attribute.outer",
					["iA"] = "@attribute.inner",
					["aF"] = "@frame.outer",
					["iF"] = "@frame.inner",
				},
			},
		},
	}
end

return M
