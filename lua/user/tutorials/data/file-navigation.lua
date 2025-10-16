-- File Navigation Basics Tutorial
return {
	id = "02-file-navigation",
	name = "File Navigation Basics",
	description = "Learn how to navigate files using NvimTree and Telescope",
	difficulty = "novice",

	-- Setup runs before tutorial starts
	setup = function()
		-- Close NvimTree if it's open (ignore errors if command doesn't exist)
		pcall(vim.cmd, "NvimTreeClose")
	end,

	-- Teardown runs after tutorial ends
	teardown = function()
		-- Nothing to clean up
	end,

	-- Tutorial steps
	steps = {
		{
			title = "Open File Explorer",
			instruction = "Press `<space>ee` to toggle NvimTree (the file explorer)",
			hints = {
				"`<space>` is your leader key",
				"It's also your gateway to most custom functionality",
			},
			-- Validation function returns true when step is complete
			validate = function()
				-- Skip if we're in the tutorial sidebar
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				return vim.bo.filetype == "NvimTree"
			end,
		},
		{
			title = "Close File Explorer",
			instruction = "Press `<space>ee` again to close NvimTree",
			hints = {
				"The same set of keystokes toggles it on and off",
			},
			validate = function()
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				return vim.bo.filetype ~= "NvimTree"
			end,
		},
		{
			title = "Open Telescope File Finder",
			instruction = "Press `<space>ff` to open Telescope file finder",
			hints = {
				"`ff` means find files",
				"Can find many other things under the `<space>f` menu",
			},
			validate = function()
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				return vim.bo.filetype == "TelescopePrompt"
			end,
		},
	},
}
