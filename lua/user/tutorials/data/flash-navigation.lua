-- Flash Navigation Tutorial
local lua_buffer = [[
-- Flash Navigation Tutorial Buffer
-- This buffer demonstrates flash.nvim navigation

local function calculate_sum(a, b)
    local result = a + b
    return result
end

local function calculate_product(a, b)
    local result = a * b
    return result
end

local function calculate_difference(a, b)
    local result = a - b
    return result
end

-- Call these functions
local sum = calculate_sum(10, 20)
local product = calculate_product(5, 6)
local difference = calculate_difference(100, 50)

-- Some repeated words for practice
-- the quick brown fox jumps over the lazy dog
-- the quick brown fox jumps over the lazy dog
-- the quick brown fox jumps over the lazy dog]]

local lua_buffer_nlines = select(2, lua_buffer:gsub('\n', '\n')) + 1

return {
	id = "06-flash-navigation",
	name = "Flash Navigation",
	description = "Master quick navigation using flash.nvim",
	difficulty = "advanced",

	setup = function()
		local setup = require("tutorials.setup")

		local actions = {
			{
				type = "open_temp_file",
				extension = "lua",
				content = lua_buffer,
			},
			{ type = "set_cursor", line = 1, col = 0 },
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
			title = "Basic Flash Jump",
			instruction = [[
1. Press `s` to activate flash,
2. then type `r` then whatever **green** character appears 15 lines down, to jump to `result` on that line
]],
			hints = {
				"`s` activates Flash's jump mode.",
				"Type the starting characters of where you want to jump",
				"Flash will show labels - press the label to jump there",
				"You can also just keep typing to narrow down matches",
			},
			validate = function()
				local pos = vim.api.nvim_win_get_cursor(0)
				local line = pos[1]
				return line == 16
			end,
		},
		{
			title = "Treesitter Jump",
			instruction = [[
1. Press `d` to start deleting
1. Press `S` (Shift+s) to activate treesitter jump mode,
2. Type the green character (flash's label) appearing at the start of the function's definition two lines above
Boom! function gone!
]],
			hints = {
				"`S` uses treesitter to jump to semantic nodes, and just like `s`, it works in operator-pending mode.",
				"This is great for jumping between functions, classes, etc. and operating on them",
				"But it requires a treesitter parser for the target filetype",
			},
			validate = function()
				local is_done = vim.api.nvim_buf_line_count(0) == lua_buffer_nlines - 3
				vim.print(is_done)
				if is_done then vim.defer_fn(function() vim.cmd("undo") end, 1000) end
				return is_done
			end
		},
		{
			title = "Yank with Remote Flash",
			instruction = [[
The intention here is to copy calculate_product(a, b) from line 9 **without moving to that line**.

1. Move cursor to last line by pressing `G`, press `o` for a new line, then `<Esc>` to return to normal mode
2. Then press `yr` to start yanking; `r` sets flash in remote mode
3. Type `ca` and then the flash label appearing at the target function label 19 lines above
4. Type `$` to yank until end of line, then `p` to paste!

Let that sink in for a moment]],
			hints = {
				"`r` is 'remote' flash - it works best with operators",
				"`yr` means 'yank remote' - like `yt` but with flash labels",
				"Remote operations work with any vim operator: d, c, y, >, <, etc.",
				"Note: this seems cool and fancy but you can have similar effects with <c-o>/<c-i>",
			},
			validate = function()
				local last_line_num = vim.api.nvim_buf_line_count(0)
				local last_line = vim.api.nvim_buf_get_lines(0, last_line_num - 1, last_line_num, false)[1]
				local is_done = last_line:find("calculate_product%(a, b%)") ~= nil
				if is_done then vim.defer_fn(function()
					vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(lua_buffer, '\n'))
				end, 2000) end
				return is_done
			end
		},
		{
			title = "Toggle Flash in Search",
			instruction = [[
Press `/` to start a search, then press `<c-s>` to toggle flash highlighting.
Try searching for 'calculate'.
Use :TutorialNext when done]],
			hints = {
				"`Ctrl+s` toggles flash mode during search",
				"Flash shows jump labels for all search matches",
			},
		},
	},
}
