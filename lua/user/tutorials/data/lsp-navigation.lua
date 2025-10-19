-- LSP Navigation Tutorial
local lua_buffer = [[
-- some random function
local function dummy_func(arg1, arg2, arg3)
    return true
end

-- this is an undefined function
some_unknown_funtion(dummy_func(1, 2, random));

-- wanna use my function here
dummy_func()]]

return {
	id = "04-lsp-navigation",
	name = "LSP Navigation",
	description = "Master navigating through code entities",
	difficulty = "novice",

	setup = function()
		local setup = require("tutorials.setup")

		local actions = {
			{
				type = "open_temp_file",
				extension = "lua",
				content = lua_buffer,
			},
			{ type = "set_cursor", line = 10, col = 0 },
			{ type = "save_layout", value = true },
		}

		for _, action in ipairs(actions) do
			local ok, err = setup.execute_action(action)
			if not ok then
				return false, err
			end
		end

		return true
	end,

	teardown = function()
		local setup = require("tutorials.setup")
		setup.execute_actions({ { type = "close_all_tutorial_buffers" }, { type = "restore_layout" } })
	end,

	steps = {
		{
			title = "Go to Definition",
			instruction = "Press `gD` while your cursor is on `dummy_func` (line 10) to jump to its definition",
			hints = {
				"`gD` is the standard LSP 'go to declaration' keymap",
				"You can also use `<leader>ld` or `<leader>lD` to search definitions with Snacks.picker",
			},
			validate = function()
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				local pos = vim.api.nvim_win_get_cursor(0)
				local line = pos[1]
				if line == 2 then
					local line_content = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1]
					if line_content and line_content:match("local function dummy_func") then
						return true
					end
				end
				return false
			end,
		},
		{
			title = "Find References",
			instruction = "Press `<leader>lR` to find all references to `dummy_func` using Snacks.picker, then close with `<Esc><Esc>` and use :TutorialNext",
			hints = {
				"<leader>lR opens Snacks.picker's LSP references picker",
				"This shows all places where the symbol is used in your code",
			},
		},
		{
			title = "View Document Symbols",
			instruction = [[
Press `<leader>ls` to view all symbols in the current document,
then close with <Esc><Esc> and use :TutorialNext

> You may have to alter the buffer for the diagnostics to show up; they are lazy]],
			hints = {
				"`<leader>ls` opens the document symbols picker",
				"This gives you an outline of all functions, variables, etc.",
				"Great for quickly navigating large files",
				"Navigating documents symbols can also be done through `<leader>nn`, although that takes more f a hierarchical approach to it",
			},
		},
		{
			title = "Check Diagnostics",
			instruction = "Press `<leader>lg` to view diagnostics, then close with <Esc><Esc> and use :TutorialNext",
			hints = {
				"<leader>lg shows all LSP diagnostics using Snacks.picker",
				"The undefined function on line 7 should show up as an error",
				"You can also use <leader>lj and <leader>lk to jump between diagnostics",
			},
			-- Manual advancement
		},
		{
			title = "Rename Symbol",
			instruction = "Move your cursor to `dummy_func` on any line and press <leader>lr to try the rename function (cancel with <Esc>), then use :TutorialNext",
			hints = {
				"<leader>lr triggers LSP rename",
				"This will rename the symbol everywhere it's used in your project",
				"Type a new name or press Esc to cancel without making changes",
			},
			-- Manual advancement
		},
	},
}
