-- Tutorial state manager and progression controller
local M = {}

local setup = require("tutorials.setup")
local ui = require("tutorials.ui")

-- Current state
M.state = {
	active = false,
	current_tutorial = nil,
	current_step = 0,
	tutorials = nil,
	hint_index = 1,
	progress_file = vim.fn.stdpath("state") .. "/tutorial-progress.json",
	autocommand_ids = {},
	advancing_step = false, -- Flag to prevent multiple advancement calls
}

-- Load progress from disk
local function load_progress()
	local file = io.open(M.state.progress_file, "r")
	if not file then
		return {}
	end

	local content = file:read("*all")
	file:close()

	local ok, data = pcall(vim.json.decode, content)
	if not ok then
		return {}
	end

	return data or {}
end

-- Save progress to disk
local function save_progress(tutorial_id, completed)
	local progress = load_progress()

	progress[tutorial_id] = {
		completed = completed,
		last_attempt = os.time(),
	}

	local content = vim.json.encode(progress)
	local file = io.open(M.state.progress_file, "w")
	if file then
		file:write(content)
		file:close()
	end
end

-- Validation handlers for different validation types
local validators = {}

function validators.filetype(validation)
	-- Skip validation if we're in the tutorial sidebar
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname:match("Tutorial$") then
		return false
	end

	return vim.bo.filetype == validation.value
end

function validators.buffer_name(validation)
	local buf_name = vim.api.nvim_buf_get_name(0)

	-- Skip validation if we're in the tutorial sidebar
	if buf_name:match("Tutorial$") then
		return false
	end

	if validation.pattern then
		return buf_name:match(validation.pattern) ~= nil
	end
	return buf_name == validation.value
end

function validators.window_count(validation)
	local count = #vim.api.nvim_list_wins()
	local expected = validation.value

	if validation.operator == ">" then
		return count > expected
	elseif validation.operator == "<" then
		return count < expected
	elseif validation.operator == ">=" then
		return count >= expected
	elseif validation.operator == "<=" then
		return count <= expected
	else
		return count == expected
	end
end

function validators.buffer_count(validation)
	local count = #vim.api.nvim_list_bufs()
	local expected = validation.value

	if validation.operator == ">" then
		return count > expected
	elseif validation.operator == "<" then
		return count < expected
	elseif validation.operator == ">=" then
		return count >= expected
	elseif validation.operator == "<=" then
		return count <= expected
	else
		return count == expected
	end
end

function validators.cursor_position(validation)
	local pos = vim.api.nvim_win_get_cursor(0)
	local line, col = pos[1], pos[2]

	if validation.line and validation.line ~= line then
		return false
	end

	if validation.col and validation.col ~= col then
		return false
	end

	return true
end

function validators.command(validation)
	local cmd = validation.command
	if not cmd then
		return false
	end

	local ok, result = pcall(vim.api.nvim_exec2, cmd, { output = true })
	if not ok then
		return false
	end

	if validation.output then
		return result.output:match(validation.output) ~= nil
	end

	return true
end

function validators.window_position(validation)
	local current_win = vim.api.nvim_get_current_win()
	local position = validation.value

	-- Try to move in the opposite direction and check if we moved
	local test_movements = {
		left = "l",
		right = "h",
		top = "j",
		bottom = "k",
	}

	local movement = test_movements[position]
	if not movement then
		return false
	end

	-- Save current window
	local before_win = current_win

	-- Try to move
	vim.cmd("wincmd " .. movement)
	local after_win = vim.api.nvim_get_current_win()

	-- Restore position
	vim.api.nvim_set_current_win(before_win)

	-- If we couldn't move, we're at the edge in that direction
	return before_win == after_win
end

function validators.lua_function(validation)
	-- Skip validation if we're in the tutorial sidebar
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname:match("Tutorial$") then
		return false
	end

	local func_code = validation.function_code
	if not func_code then
		return false
	end

	-- Load the function code
	local ok, loader = pcall(loadstring, "return " .. func_code)
	if not ok then
		return false
	end

	-- Call the loader to get the actual validation function
	local success, func = pcall(loader)
	if not success then
		return false
	end

	-- Call the validation function to get the boolean result
	local success2, result = pcall(func)
	return success2 and result == true
end

-- Validate current step
local function validate_step(step)
	-- If step has a validate function, call it directly
	if step.validate and type(step.validate) == "function" then
		local ok, result = pcall(step.validate)
		return ok and result == true
	end

	-- Fallback: no validation means step is always valid (manual advancement only)
	return false
end

-- Update UI for current step
local function update_step_ui()
	if not M.state.active or not M.state.current_tutorial then
		return
	end

	local tutorial = M.state.current_tutorial
	local step = tutorial.steps[M.state.current_step]

	if not step then
		return
	end

	ui.show_step(tutorial, step, M.state.current_step, #tutorial.steps)
end

-- Check if step is complete and auto-advance
local function check_step_completion()
	if not M.state.active or not M.state.current_tutorial then
		return
	end

	-- Prevent advancement while already advancing
	if M.state.advancing_step then
		return
	end

	local tutorial = M.state.current_tutorial
	local step = tutorial.steps[M.state.current_step]

	if not step then
		return
	end

	if validate_step(step) then
		-- Mark as advancing to prevent duplicate calls
		M.state.advancing_step = true

		-- Auto-advance to next step (sidebar will update automatically)
		vim.defer_fn(function()
			M.next_step()
			-- Allow new validations after advancing
			M.state.advancing_step = false
		end, 500)
	end
end

-- Set up autocommands for validation
local function setup_validation_autocommands()
	-- Clear previous autocommands
	for _, id in ipairs(M.state.autocommand_ids) do
		pcall(vim.api.nvim_del_autocmd, id)
	end
	M.state.autocommand_ids = {}

	-- Create autocommand group
	local group = vim.api.nvim_create_augroup("TutorialValidation", { clear = true })

	-- Events to check for validation
	local events = {
		"BufEnter", "WinEnter", "WinNew", "WinClosed",
		"CursorMoved", "CursorMovedI", "ModeChanged",
		"TextChanged", "TextChangedI", "FileType",
	}

	local id = vim.api.nvim_create_autocmd(events, {
		group = group,
		callback = function()
			vim.defer_fn(check_step_completion, 100)
		end,
	})

	table.insert(M.state.autocommand_ids, id)
end

-- Load tutorials from Lua files
function M.load_tutorials()
	local config_path = vim.fn.stdpath("config")
	local tutorial_dir = config_path .. "/lua/user/tutorials/data"

	-- Find all .lua files in the tutorials data directory
	local tutorial_files = vim.fn.glob(tutorial_dir .. "/*.lua", false, true)

	local tutorials = {}
	for _, file in ipairs(tutorial_files) do
		-- Extract module name from file path
		local module_name = file:match("([^/]+)%.lua$")
		if module_name and module_name ~= "init" then
			local ok, tutorial = pcall(require, "user.tutorials.data." .. module_name)
			if ok and type(tutorial) == "table" and tutorial.id then
				table.insert(tutorials, tutorial)
			else
				vim.notify("Failed to load tutorial: " .. module_name, vim.log.levels.WARN)
			end
		end
	end

	if #tutorials == 0 then
		ui.show_error("No tutorials found")
		return false
	end

	M.state.tutorials = tutorials
	return true
end

-- Start a tutorial
function M.start_tutorial(tutorial_id)
	if M.state.active then
		ui.show_error("A tutorial is already active. Use :TutorialQuit to exit.")
		return
	end

	if not M.state.tutorials then
		if not M.load_tutorials() then
			return
		end
	end

	-- Find tutorial by ID
	local tutorial = nil
	for _, t in ipairs(M.state.tutorials) do
		if t.id == tutorial_id then
			tutorial = t
			break
		end
	end

	if not tutorial then
		ui.show_error("Tutorial not found: " .. tutorial_id)
		return
	end

	-- Run setup if it exists
	if tutorial.setup and type(tutorial.setup) == "function" then
		local ok, err = pcall(tutorial.setup)
		if not ok then
			ui.show_error("Setup failed: " .. tostring(err))
			return
		end
	end

	-- Initialize state
	M.state.active = true
	M.state.current_tutorial = tutorial
	M.state.current_step = 1
	M.state.hint_index = 1
	M.state.advancing_step = false

	-- Set up validation
	setup_validation_autocommands()

	-- Show first step
	update_step_ui()
end

-- Go to next step
function M.next_step()
	if not M.state.active or not M.state.current_tutorial then
		ui.show_error("No active tutorial")
		return
	end

	local tutorial = M.state.current_tutorial

	if M.state.current_step >= #tutorial.steps then
		-- Tutorial complete
		save_progress(tutorial.id, true)

		-- Clear autocommands immediately to prevent validation during completion
		for _, id in ipairs(M.state.autocommand_ids) do
			pcall(vim.api.nvim_del_autocmd, id)
		end
		M.state.autocommand_ids = {}

		-- Run teardown immediately
		if tutorial.teardown and type(tutorial.teardown) == "function" then
			pcall(tutorial.teardown)
		end

		-- Show congratulations and quit silently after delay
		ui.show_tutorial_complete(tutorial, function()
			M.quit_tutorial(true) -- true = silent (no "Tutorial exited" message)
		end)
		return
	end

	M.state.current_step = M.state.current_step + 1
	M.state.hint_index = 1
	update_step_ui()
end

-- Go to previous step
function M.prev_step()
	if not M.state.active or not M.state.current_tutorial then
		ui.show_error("No active tutorial")
		return
	end

	if M.state.current_step <= 1 then
		ui.show_info("Already at the first step")
		return
	end

	M.state.current_step = M.state.current_step - 1
	M.state.hint_index = 1
	M.state.advancing_step = false -- Reset advancement flag
	update_step_ui()
end

-- Show hint for current step
function M.show_hint()
	if not M.state.active or not M.state.current_tutorial then
		ui.show_error("No active tutorial")
		return
	end

	local tutorial = M.state.current_tutorial
	local step = tutorial.steps[M.state.current_step]

	ui.show_hint(step, M.state.hint_index)

	-- Advance hint index for next call
	if step.hints then
		M.state.hint_index = math.min(M.state.hint_index + 1, #step.hints)
	end
end

-- Restart current tutorial
function M.restart_tutorial()
	if not M.state.active or not M.state.current_tutorial then
		ui.show_error("No active tutorial")
		return
	end

	local tutorial_id = M.state.current_tutorial.id
	M.quit_tutorial()
	vim.defer_fn(function()
		M.start_tutorial(tutorial_id)
	end, 500)
end

-- Quit current tutorial
function M.quit_tutorial(silent)
	if not M.state.active then
		return
	end

	-- Run teardown if it exists
	if M.state.current_tutorial and M.state.current_tutorial.teardown and type(M.state.current_tutorial.teardown) == "function" then
		pcall(M.state.current_tutorial.teardown)
	end

	-- Clear autocommands
	for _, id in ipairs(M.state.autocommand_ids) do
		pcall(vim.api.nvim_del_autocmd, id)
	end

	-- Close UI (only if not already closed by completion message)
	if not silent then
		ui.close_notification()
	end

	-- Reset state
	M.state.active = false
	M.state.current_tutorial = nil
	M.state.current_step = 0
	M.state.hint_index = 1
	M.state.autocommand_ids = {}

	-- Only show exit message if not silent
	if not silent then
		ui.show_info("Tutorial exited")
	end
end

-- Show tutorial picker
function M.show_picker()
	if M.state.active then
		ui.show_error("A tutorial is already active. Use :TutorialQuit to exit.")
		return
	end

	if not M.state.tutorials then
		if not M.load_tutorials() then
			return
		end
	end

	ui.show_tutorial_picker(M.state.tutorials, function(tutorial)
		M.start_tutorial(tutorial.id)
	end)
end

return M
