local M = {
	"nvim-treesitter/nvim-treesitter-textobjects",
	event = "VeryLazy",
	keys = nil,
	branch = "main"
}

M.config = function()
	require("nvim-treesitter-textobjects").setup {
		select = {
			lookahead = true,
			selection_modes = {
				['@parameter.outer'] = 'v', -- charwise
				['@function.outer'] = 'V', -- linewise
				['@class.outer'] = '<c-v>', -- blockwise
			},
			include_surrounding_whitespace = false,
		},
		move = {
			set_jumps = true,
		},
	}
	-- keymaps
	vim.keymap.set({ "x", "o" }, "af", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@function.outer", "textobjects")
	end, { expr = true, desc = 'outer function' })
	vim.keymap.set({ "x", "o" }, "if", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@function.inner", "textobjects")
	end, { expr = true, desc = 'inner function' })
	vim.keymap.set({ "x", "o" }, "ac", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@class.outer", "textobjects")
	end, { expr = true, desc = 'outer class' })
	vim.keymap.set({ "x", "o" }, "ic", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@class.inner", "textobjects")
	end, { expr = true, desc = 'inner class' })
	vim.keymap.set({ "x", "o" }, "al", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@loop.outer", "textobjects")
	end, { expr = true, desc = 'outer loop' })
	vim.keymap.set({ "x", "o" }, "il", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@loop.inner", "textobjects")
	end, { expr = true, desc = 'inner loop' })
	vim.keymap.set({ "x", "o" }, "ai", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@condition.outer", "textobjects")
	end, { expr = true, desc = 'outer condition' })
	vim.keymap.set({ "x", "o" }, "ii", function()
		require "nvim-treesitter-textobjects.select".select_textobject("@condition.inner", "textobjects")
	end, { expr = true, desc = 'inner condition' })
end

return M
