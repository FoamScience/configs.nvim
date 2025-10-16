-- Initial state setup and teardown handler for tutorials
local M = {}

-- State tracking for cleanup
M.tutorial_state = {
	buffers = {},      -- Buffers created by tutorial
	windows = {},      -- Windows created by tutorial
	saved_layout = nil, -- Saved window layout
	saved_options = {}, -- Saved vim options
}

-- Helper: Create a scratch buffer with optional content
local function create_scratch_buffer(content, filetype)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
	vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')

	if content then
		local lines = vim.split(content, "\n")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	end

	if filetype then
		vim.api.nvim_buf_set_option(bufnr, 'filetype', filetype)
	end

	return bufnr
end

-- Helper: Get window layout for saving/restoring
local function get_window_layout()
	return {
		layout = vim.fn.winlayout(),
		current_win = vim.api.nvim_get_current_win(),
		windows = vim.api.nvim_list_wins(),
	}
end

-- Action handlers
local action_handlers = {}

function action_handlers.open_file(action)
	local path = action.path or ":enew"
	local content = action.content
	local filetype = action.filetype

	if path == ":enew" or not path then
		-- Create new scratch buffer
		local bufnr = create_scratch_buffer(content, filetype)
		vim.api.nvim_set_current_buf(bufnr)
		table.insert(M.tutorial_state.buffers, bufnr)
	else
		-- Open actual file
		vim.cmd("edit " .. vim.fn.fnameescape(path))
		if content then
			vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(content, "\n"))
		end
		if filetype then
			vim.bo.filetype = filetype
		end
		table.insert(M.tutorial_state.buffers, vim.api.nvim_get_current_buf())
	end

	return true
end

function action_handlers.open_temp_file(action)
	local extension = action.extension or "txt"
	local content = action.content or ""
	local filename = string.format("/tmp/nvim_tutorial_%s_%s.%s",
		os.time(), math.random(1000, 9999), extension)

	local file = io.open(filename, "w")
	if file then
		file:write(content)
		file:close()
	end

	vim.cmd("edit " .. vim.fn.fnameescape(filename))
	table.insert(M.tutorial_state.buffers, vim.api.nvim_get_current_buf())
	return true
end

function action_handlers.set_filetype(action)
	local filetype = action.filetype
	if not filetype then
		return false, "set_filetype requires 'filetype' field"
	end
	vim.bo.filetype = filetype
	return true
end

function action_handlers.split(action)
	local direction = action.direction or "vertical"

	if direction == "vertical" then
		vim.cmd("vsplit")
	elseif direction == "horizontal" then
		vim.cmd("split")
	else
		return false, "Invalid split direction: " .. direction
	end

	table.insert(M.tutorial_state.windows, vim.api.nvim_get_current_win())
	return true
end

function action_handlers.resize(action)
	local width = action.width
	local height = action.height

	if width then
		vim.cmd("vertical resize " .. width)
	end
	if height then
		vim.cmd("resize " .. height)
	end

	return true
end

function action_handlers.focus_window(action)
	local position = action.position -- "top", "bottom", "left", "right", or number

	if type(position) == "number" then
		vim.cmd(position .. "wincmd w")
	elseif position == "top" then
		vim.cmd("wincmd k")
	elseif position == "bottom" then
		vim.cmd("wincmd j")
	elseif position == "left" then
		vim.cmd("wincmd h")
	elseif position == "right" then
		vim.cmd("wincmd l")
	else
		return false, "Invalid window position: " .. tostring(position)
	end

	return true
end

function action_handlers.command(action)
	local cmd = action.cmd
	if not cmd then
		return false, "command action requires 'cmd' field"
	end

	local ok, err = pcall(vim.cmd, cmd)
	if not ok then
		-- If ignore_errors is set, silently continue
		if action.ignore_errors then
			return true
		end
		return false, "Command failed: " .. tostring(err)
	end

	return true
end

function action_handlers.lua(action)
	local code = action.code
	if not code then
		return false, "lua action requires 'code' field"
	end

	local ok, err = pcall(function()
		loadstring(code)()
	end)

	if not ok then
		return false, "Lua code failed: " .. tostring(err)
	end

	return true
end

function action_handlers.set_option(action)
	local option = action.option
	local value = action.value
	local scope = action.scope or "local" -- "local", "global", "buffer", "window"

	if not option then
		return false, "set_option requires 'option' field"
	end

	-- Save original value for restoration
	local original_value
	if scope == "global" then
		original_value = vim.o[option]
		vim.o[option] = value
	elseif scope == "buffer" then
		original_value = vim.bo[option]
		vim.bo[option] = value
	elseif scope == "window" then
		original_value = vim.wo[option]
		vim.wo[option] = value
	else
		original_value = vim.opt_local[option]:get()
		vim.opt_local[option] = value
	end

	M.tutorial_state.saved_options[option] = {
		value = original_value,
		scope = scope,
	}

	return true
end

function action_handlers.save_layout(action)
	M.tutorial_state.saved_layout = get_window_layout()
	return true
end

function action_handlers.mark_buffers(action)
	-- Mark all current buffers as tutorial-owned
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			table.insert(M.tutorial_state.buffers, bufnr)
		end
	end
	return true
end

function action_handlers.set_cursor(action)
	local line = action.line or 1
	local col = action.col or 0
	local win = action.window or 0  -- 0 = current window

	if not vim.api.nvim_win_is_valid(win) and win ~= 0 then
		return false, "Invalid window"
	end

	-- Ensure line is within buffer bounds
	local buf = vim.api.nvim_win_get_buf(win)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if line > line_count then
		line = line_count
	end
	if line < 1 then
		line = 1
	end

	-- Set cursor position (line is 1-indexed, col is 0-indexed)
	vim.api.nvim_win_set_cursor(win, {line, col})
	return true
end

function action_handlers.restore_layout(action)
	if not M.tutorial_state.saved_layout then
		return true -- Nothing to restore
	end

	-- Close all windows except the first
	local windows = vim.api.nvim_list_wins()
	for i = 2, #windows do
		if vim.api.nvim_win_is_valid(windows[i]) then
			vim.api.nvim_win_close(windows[i], true)
		end
	end

	M.tutorial_state.saved_layout = nil
	return true
end

function action_handlers.close_all_tutorial_buffers(action)
	for _, bufnr in ipairs(M.tutorial_state.buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		end
	end
	M.tutorial_state.buffers = {}
	return true
end

-- Execute a single action
function M.execute_action(action)
	local handler = action_handlers[action.type]
	if not handler then
		return false, "Unknown action type: " .. action.type
	end

	return handler(action)
end

-- Execute a list of actions (setup or teardown)
function M.execute_actions(actions)
	if not actions then
		return true
	end

	for idx, action in ipairs(actions) do
		local ok, err = M.execute_action(action)
		if not ok then
			return false, string.format("Action %d failed: %s", idx, err or "unknown error")
		end
	end

	return true
end

-- Run setup for a tutorial
function M.run_setup(tutorial)
	-- Reset state
	M.tutorial_state = {
		buffers = {},
		windows = {},
		saved_layout = nil,
		saved_options = {},
	}

	if not tutorial.setup or not tutorial.setup.actions then
		return true
	end

	return M.execute_actions(tutorial.setup.actions)
end

-- Run teardown for a tutorial
function M.run_teardown(tutorial)
	if tutorial.teardown and tutorial.teardown.actions then
		M.execute_actions(tutorial.teardown.actions)
	end

	-- Restore saved options
	for option, saved in pairs(M.tutorial_state.saved_options) do
		if saved.scope == "global" then
			vim.o[option] = saved.value
		elseif saved.scope == "buffer" then
			vim.bo[option] = saved.value
		elseif saved.scope == "window" then
			vim.wo[option] = saved.value
		else
			vim.opt_local[option] = saved.value
		end
	end

	-- Clean up any remaining tutorial buffers
	for _, bufnr in ipairs(M.tutorial_state.buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		end
	end

	-- Reset state
	M.tutorial_state = {
		buffers = {},
		windows = {},
		saved_layout = nil,
		saved_options = {},
	}

	return true
end

return M
