-- Interactive tutorial system for Neovim configuration
-- Main entry point and command setup

-- Helper function to check if Neovim started with files
local function started_with_files()
	-- Check if any arguments were passed (excluding options starting with -)
	local args = vim.fn.argv()
	for _, arg in ipairs(args) do
		if not arg:match("^%-") then
			return true
		end
	end
	return false
end

-- Only define plugin if started without files
if started_with_files() then
	return {}
end

local M = {
	name = "user-tutorials",
	dir = vim.fn.stdpath("config") .. "/lua/user/tutorials",
	lazy = true,
	cmd = {
		"Tutorials",
		"TutorialNext",
		"TutorialPrev",
		"TutorialQuit",
		"TutorialRestart",
	},
}

function M.config()
	local manager = require("tutorials.manager")

	-- Create commands
	vim.api.nvim_create_user_command("Tutorials", function()
		manager.show_picker()
	end, {
		desc = "Open tutorial picker",
	})

	vim.api.nvim_create_user_command("TutorialNext", function()
		manager.next_step()
	end, {
		desc = "Go to next tutorial step",
	})

	vim.api.nvim_create_user_command("TutorialPrev", function()
		manager.prev_step()
	end, {
		desc = "Go to previous tutorial step",
	})

	vim.api.nvim_create_user_command("TutorialQuit", function()
		manager.quit_tutorial()
	end, {
		desc = "Exit current tutorial",
	})

	vim.api.nvim_create_user_command("TutorialRestart", function()
		manager.restart_tutorial()
	end, {
		desc = "Restart current tutorial",
	})
end

return M
