-- Window Navigation Tutorial
local setup_state = {}

return {
	id = "01-window-navigation",
	name = "Window Navigation",
	description = "Master navigating between multiple windows",
	difficulty = "novice",

	setup = function()
		local setup = require("tutorials.setup")

		-- Create three windows with buffers
		local actions = {
			{ type = "open_file", path = ":enew", content = "-- Main window\n-- This is buffer 1\n\nYou are currently in the main window.", filetype = "lua" },
			{ type = "split", direction = "vertical" },
			{ type = "open_file", path = ":enew", content = "-- Right window\n-- This is buffer 2\n\nThis window is on the right side.", filetype = "lua" },
			{ type = "command", cmd = "vertical resize +30" },
			{ type = "split", direction = "horizontal" },
			{ type = "open_file", path = ":enew", content = "-- Bottom-right window\n-- This is buffer 3\n\nThis window is in the bottom-right corner.", filetype = "lua" },
			{ type = "command", cmd = "wincmd h" },
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
			title = "Navigate to Right Window",
			instruction = "Use `<c-w> followed by `l` (or press `<Tab>`, or `<c-w> followed by `w`) to move to the window on the right",
			hints = {
				"`<c-w> is the default vim window command prefix; too fundamental to change",
			},
			validate = function()
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				local pos = vim.api.nvim_win_get_position(0)
				return pos[2] > 0
			end,
		},
		{
			title = "Navigate to Bottom Window",
			instruction = "Press `<c-w>` followed by `j` to move to the window below",
			hints = {
				"Or the `<Tab>`, or `<c-w>` followed `w`"
			},
			validate = function()
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				local content = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
				return content and content:match("Bottom%-right") ~= nil
			end,
		},
		{
			title = "Navigate Back to Left",
			instruction = "Press <c-w> followed by `h` to move to the window on the left",
			hints = {
				"`<Tab>` will not work",
			},
			validate = function()
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname:match("Tutorial$") then
					return false
				end
				local pos = vim.api.nvim_win_get_position(0)
				return pos[2] == 0
			end,
		},
		{
			title = "Close Current Window",
			instruction = "Press `<c-w>` followed by `c` to close the current window",
			hints = {
				"When there are more loaded buffers than windows, `<Tabs>` cycles buffers"
			},
			validate = function()
				return #vim.api.nvim_list_wins() == 2
			end,
		},
	},
}
