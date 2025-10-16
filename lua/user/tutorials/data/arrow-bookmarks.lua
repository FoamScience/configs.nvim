-- Arrow Bookmarks Tutorial
local file1_content = [[
-- File 1: Main Application
local app = {}

function app.initialize()
    print("Initializing application...")
    return true
end

function app.run()
    print("Running application...")
    -- Main application loop
end

return app
]]

local file2_content = [[
-- File 2: Configuration
local config = {
    version = "1.0.0",
    debug = false,
    port = 8080
}

function config.load()
    print("Loading configuration...")
end

return config
]]

return {
	id = "05-arrow-bookmarks",
	name = "Arrow Bookmarks",
	description = "Learn to use Arrow for quick file bookmarking and project navigation",
	difficulty = "novice",

	setup = function()
		local setup = require("tutorials.setup")

		local actions = {
			-- Create first file
			{
				type = "open_temp_file",
				extension = "lua",
				content = file1_content,
			},
			{ type = "save_layout", value = true },
		}

		for _, action in ipairs(actions) do
			local ok, err = setup.execute_action(action)
			if not ok then
				return false, err
			end
		end

		-- Create second file
		vim.cmd("tabnew")
		local file2 = io.open("/tmp/nvim_tutorial_config_" .. os.time() .. ".lua", "w")
		if file2 then
			file2:write(file2_content)
			file2:close()
		end
		vim.cmd("edit " .. "/tmp/nvim_tutorial_config_" .. os.time() .. ".lua")

		-- Return to first tab
		vim.cmd("tabfirst")
		vim.cmd("cd /tmp")

		return true
	end,

	teardown = function()
		local setup = require("tutorials.setup")
		vim.cmd("tabonly")
		setup.execute_actions({ { type = "close_all_tutorial_buffers" }, { type = "restore_layout" } })
	end,

	steps = {
		{
			title = "Open Arrow Menu",
			instruction = [[
Press `,` to open the Arrow bookmarks menu.
You should see it's currently empty.
Close it with `,` again and use `:TutorialNext`]],
			hints = {
				"Arrow is a bookmarking plugin that lets you save and quickly jump to important files",
				"Use `<leader>nb` stands for 'navigation bookmarks' or just `,`",
				"The menu shows all your bookmarked files for your current project",
			},
		},
		{
			title = "Add a Bookmark",
			instruction = [[
Press `,` then `s` to bookmark the current file.
You should see a confirmation.
Use `:TutorialNext` to continue]],
			hints = {
				"Each bookmark is saved per project",
				"Bookmarks will persist across Neovim sessions",
			},
		},
		{
			title = "Bookmark Second File",
			instruction = [[
Press `<Tab>` or `gt` to go to the next tab.
Press `,s` again to bookmark this second file.
Use `:TutorialNext` when ready]],
			hints = {
				"We're moving to another file to bookmark it too",
				"Arrow bookmarks are numbered for quick access",
			},
		},
		{
			title = "View All Bookmarks",
			instruction = [[
Press `,` to open the Arrow menu again.
You should now see both bookmarked files listed.
Close with `<Esc>` and use `:TutorialNext`]],
			hints = {
				"The menu shows file names and paths",
				"Bookmarks are numbered starting from 1",
				"You can select the buffer by its number while the arrow menu is open",
				"Further shortcuts are always shown in the menu"
			},
		},
	},
}
