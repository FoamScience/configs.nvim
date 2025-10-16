-- UI layer for tutorials using floating sidebar
local M = {}

-- Sidebar state
M.sidebar = {
	bufnr = nil,
	winid = nil,
	width = 60,
	visible = false,
}

-- Icons for different UI elements
local icons = {
	tutorial = "󰗚 ",
	step = "󰮠 ",
	hint = "󰌶 ",
	success = " ",
	warning = "󰀪 ",
	error = " ",
	progress = "󰄭 ",
}

-- Create or update the sidebar window
local function ensure_sidebar()
	-- Create buffer if it doesn't exist
	if not M.sidebar.bufnr or not vim.api.nvim_buf_is_valid(M.sidebar.bufnr) then
		M.sidebar.bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_option_value('bufhidden', 'hide', {buf = M.sidebar.bufnr})
		vim.api.nvim_set_option_value('buftype', 'nofile', {buf = M.sidebar.bufnr})
		vim.api.nvim_set_option_value('swapfile', false, {buf = M.sidebar.bufnr})
		vim.api.nvim_set_option_value('filetype', 'markdown', {buf = M.sidebar.bufnr})
		vim.api.nvim_buf_set_name(M.sidebar.bufnr, 'Tutorial')
	end

	-- Create or update window
	if not M.sidebar.winid or not vim.api.nvim_win_is_valid(M.sidebar.winid) then
		local width = M.sidebar.width
		local height = math.floor((vim.o.lines - 2) * 0.95)
		local col = vim.o.columns - width

		M.sidebar.winid = vim.api.nvim_open_win(M.sidebar.bufnr, false, {
			relative = 'editor',
			width = width,
			height = height,
			col = col,
			row = 0,
			style = 'minimal',
			border = 'rounded',
			noautocmd = true,
			zindex = 900,
		})

		-- Set window options
		vim.api.nvim_set_option_value('wrap', true, {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('linebreak', true, {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('cursorline', false, {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('number', false, {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('relativenumber', false, {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('signcolumn', 'no', {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('winhl', 'Normal:NormalFloat,FloatBorder:FloatBorder', {win=M.sidebar.winid})
		vim.api.nvim_set_option_value('winfixwidth', true, {win=M.sidebar.winid})

		-- Set buffer-local keymaps to close sidebar
		local opts = { noremap = true, silent = true, buffer = M.sidebar.bufnr }
		vim.keymap.set('n', 'q', function()
			-- Don't close, just move focus away
			vim.cmd('wincmd p')
		end, opts)
		vim.keymap.set('n', '<Esc>', function()
			vim.cmd('wincmd p')
		end, opts)

		M.sidebar.visible = true
	end

	return M.sidebar.bufnr, M.sidebar.winid
end

-- Update sidebar content
local function update_sidebar(lines)
	local bufnr, _ = ensure_sidebar()

	-- Make buffer modifiable temporarily
	vim.api.nvim_set_option_value('modifiable', true, { buf = bufnr })

	-- Set content
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	-- Make buffer read-only
	vim.api.nvim_set_option_value('modifiable', false, { buf = bufnr })
end

-- Close sidebar
local function close_sidebar()
	if M.sidebar.winid and vim.api.nvim_win_is_valid(M.sidebar.winid) then
		vim.api.nvim_win_close(M.sidebar.winid, true)
		M.sidebar.winid = nil
	end
	M.sidebar.visible = false
end

-- Setup auto-resize on VimResized
local function setup_resize_handler()
	vim.api.nvim_create_autocmd("VimResized", {
		group = vim.api.nvim_create_augroup("TutorialSidebarResize", { clear = true }),
		callback = function()
			if M.sidebar.winid and vim.api.nvim_win_is_valid(M.sidebar.winid) then
				local width = M.sidebar.width
				local height = math.floor((vim.o.lines - 2) / 2)
				local col = vim.o.columns - width

				vim.api.nvim_win_set_config(M.sidebar.winid, {
					relative = 'editor',
					width = width,
					height = height,
					col = col,
					row = 0,
				})
			end
		end,
	})
end

-- Initialize on first use
local initialized = false
local function init_ui()
	if not initialized then
		setup_resize_handler()
		initialized = true
	end
end

-- Create a progress bar
local function create_progress_bar(current, total, width)
	width = width or 20
	local filled = math.floor((current / total) * width)
	local empty = width - filled

	local bar = string.rep("━", filled) .. string.rep("─", empty)
	return string.format("[%s] %d/%d", bar, current, total)
end

-- Format step instruction with title and content
local function format_step_message(tutorial, step, step_num, total_steps)
	local lines = {}

	-- Tutorial name as H1
	table.insert(lines, string.format("# %s %s", icons.tutorial, tutorial.name))
	table.insert(lines, "")

	-- Progress bar
	table.insert(lines, "**Progress:** " .. create_progress_bar(step_num, total_steps))
	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "")

	-- Step title as H2
	table.insert(lines, string.format("## %s Step %d: %s", icons.step, step_num, step.title))
	table.insert(lines, "")

	-- Instruction
	table.insert(lines, step.instruction)
	table.insert(lines, "")

	-- Hints section (if available)
	if step.hints and #step.hints > 0 then
		table.insert(lines, "---")
		table.insert(lines, "")
		table.insert(lines, string.format("### %s Hints", icons.hint))
		table.insert(lines, "")
		for _, hint in ipairs(step.hints) do
			table.insert(lines, "- " .. hint)
		end
		table.insert(lines, "")
	end

	return table.concat(lines, "\n")
end

-- Show a persistent sidebar for the current step
function M.show_step(tutorial, step, step_num, total_steps)
	init_ui()

	local message = format_step_message(tutorial, step, step_num, total_steps)
	local lines = vim.split(message, "\n")

	-- Add padding
	local padded_lines = {}
	table.insert(padded_lines, "")
	for _, line in ipairs(lines) do
		table.insert(padded_lines, " " .. line)
	end
	table.insert(padded_lines, "")

	update_sidebar(padded_lines)
end

-- Update notification when step is completed
function M.show_step_complete(step_title)
	require("snacks").notify.notify(
		string.format("Completed: %s", step_title),
		{
			title = "Step Complete",
			level = "info",
			icon = icons.success,
			timeout = 2000,
		}
	)
end

-- Show hint for current step
function M.show_hint(step, hint_index)
	if not step.hints or #step.hints == 0 then
		require("snacks").notify.notify("No hints available for this step", {
			title = "Hint",
			level = "warn",
			icon = icons.warning,
		})
		return
	end

	hint_index = hint_index or 1
	if hint_index > #step.hints then
		hint_index = #step.hints
	end

	local hint = step.hints[hint_index]
	local message = string.format("%s Hint %d/%d:\n\n%s",
		icons.hint, hint_index, #step.hints, hint)

	require("snacks").notify.notify(message, {
		title = "Tutorial Hint",
		level = "info",
		timeout = 5000,
	})
end

-- Show tutorial completion
function M.show_tutorial_complete(tutorial, on_complete)
	-- Update sidebar with completion message
	local completion_lines = {
		"",
		" # %s Congratulations!",
		"",
		string.format(" You've completed the **%s** tutorial!", tutorial.name),
		"",
		" ---",
		"",
		" *The sidebar will close in 3 seconds...*",
		"",
	}

	-- Format with success icon
	completion_lines[2] = string.format(completion_lines[2], icons.success)

	update_sidebar(completion_lines)

	-- Also show a notification
	require("snacks").notify.notify(
		string.format("Completed: %s tutorial!", tutorial.name),
		{
			title = "Tutorial Complete",
			level = "info",
			icon = icons.success,
			timeout = 3000,
		}
	)

	-- Close sidebar and call completion callback after delay
	vim.defer_fn(function()
		M.close_notification()
		if on_complete and type(on_complete) == "function" then
			on_complete()
		end
	end, 3000)
end

-- Show error message
function M.show_error(message)
	require("snacks").notify.notify(message, {
		title = "Tutorial Error",
		level = "error",
		icon = icons.error,
	})
end

-- Show info message
function M.show_info(message)
	require("snacks").notify.notify(message, {
		title = "Tutorial",
		level = "info",
	})
end

-- Close current persistent sidebar
function M.close_notification()
	close_sidebar()
end

-- Show tutorial picker using vim.ui.select
function M.show_tutorial_picker(tutorials, on_select)
	table.sort(tutorials, function(a, b)
		return (a.id or 0) < (b.id or 0)
	end)
	local items = {}
	local tutorial_map = {}

	for _, tutorial in ipairs(tutorials) do
		local difficulty = tutorial.difficulty or "unknown"
		local step_count = #tutorial.steps
		local label = string.format("%s [%s] - %d steps",
			tutorial.name, difficulty, step_count)
		table.insert(items, label)
		tutorial_map[label] = tutorial
	end

	vim.ui.select(items, {
		prompt = "Select Tutorial:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice and tutorial_map[choice] then
			on_select(tutorial_map[choice])
		end
	end)
end

return M
