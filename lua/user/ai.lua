-- A small Lua script to run LLM-based AI assistants on Neovim Buffers
-- Requires a `chat` command to be available in PATH

-- Check if chat command is available
-- returns nil if not available, true if available
local function check_chat()
    if vim.fn.executable("chat") == 0 then
        vim.notify(
            [[chat command not found; a GPT-like CMD tool is required that can run
        --`chat -q <prompt>` and write results to stdout.]],
            vim.log.levels.WARN
        )
        return nil
    end
    return true
end

local M = {}

-- set empty code_reviews
M.code_reviews = {}

-- process data from chat command
M.process_data = function(data)
    local on = false
    local json_data = ""
    for _, line in ipairs(data) do
        if line == "[" then
            on = true
        end
        if on then
            json_data = json_data .. line
        end
        if line == "]" then
            on = false
            break
        end
    end
    if on then
        vim.notify("Response from AI agent didn't adhere to expected structure.", vim.log.levels.WARN)
        return nil
    end
    local success, res = pcall(vim.json.decode, json_data)
    if success then
        M.code_reviews[vim.api.nvim_get_current_buf()] = res
    else
        vim.notify("Response from AI agent didn't adhere to expected structure.", vim.log.levels.WARN)
        return nil
    end
    M.render_code_reviews(M.code_reviews, vim.api.nvim_get_current_buf())
end

-- render code reviews as a Telescope list
M.render_code_reviews = function(reviews, bufnr)
    if reviews[bufnr] == nil then
        vim.notify("No code reviews found!", vim.log.levels.WARN)
        return nil
    end
    local pickers = require("telescope.pickers")
    local previewers = require("telescope.previewers")
    pickers
        .new({}, {
            prompt_title = "Code Reviews",
            finder = require("telescope.finders").new_table({
                results = reviews[bufnr],
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = "[" .. entry.severity .. "|" .. entry.line .. "] " .. entry.message,
                        ordinal = entry.message,
                        bufnr = bufnr,
                    }
                end,
            }),
            sorter = require("telescope.config").values.generic_sorter({}),
            previewer = previewers.new_buffer_previewer({
                define_preview = function(self, entry, status)
                    -- get line number and code text
                    local line = entry.value.line
                    -- get context lines
                    local num_rows = vim.api.nvim_win_get_height(status.preview_win) - 1
                    local lines =
                        vim.api.nvim_buf_get_lines(entry.bufnr, line - num_rows / 2, line + num_rows / 2, true)
                    -- populate buffer
                    local state_bufnr = self.state.bufnr
                    self.state.buf = vim.api.nvim_create_buf(false, true)
                    vim.api.nvim_buf_set_lines(state_bufnr, 0, -1, false, lines)
                    local hl_line = math.floor(num_rows / 2 - 1)
                    vim.api.nvim_buf_add_highlight(state_bufnr, -1, "TelescopePreviewMatch", hl_line, 0, -1)
                    vim.bo[state_bufnr].ft = entry.value.lang
                end,
            }),
            attach_mappings = function(prompt_bufnr, map)
                local select_review = function()
                    local selection = require("telescope.actions.state").get_selected_entry()
                    require("telescope.actions").close(prompt_bufnr)
                    local line = selection.value.line
                    local severity = selection.value.severity
                    local message = selection.value.message
                    local cur_bufnr = vim.api.nvim_get_current_buf()
                    local ns = vim.api.nvim_create_namespace("chat")
                    vim.api.nvim_buf_clear_namespace(cur_bufnr, ns, 0, -1)
                    vim.api.nvim_buf_set_extmark(
                        cur_bufnr,
                        ns,
                        line - 1,
                        0,
                        { virt_text = { { " ■ " .. severity .. ": " .. message, "@lsp.type.parameter" } } }
                    )
                    vim.api.nvim_win_set_cursor(0, { line, 0 })
                end
                map("i", "<CR>", select_review)
                map("n", "<CR>", select_review)
                return true
            end,
        })
        :find()
end

-- Generic Chat prompting
M.run_chat = function(promptstring, buf_ft)
    if check_chat() == nil then
        return nil
    end
    local is_code_review = buf_ft == "json"
    -- Get line start and end of visual selection
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")
    if vstart == nil or vend == nil then
        vim.notify("No visual selection found!", vim.log.levels.WARN)
        return nil
    end
    local line_start = vstart[2]
    local line_end = vend[2]
    local lines = vim.fn.getline(line_start, line_end)
    local counter = 0
    lines = vim.tbl_map(function(line)
        if counter == 0 then return line end
        line = "@" .. line_start + counter .. "@ " .. line
        counter = counter + 1
        return line
    end, lines)
    -- Process prompt
    local code_promptstring = promptstring
    if is_code_review then
        code_promptstring = promptstring
            .. ".\nProvide no introductory text and no explanations."
            .. "\nCode line numbers are indicated at the start of each line by the format `@<line>@`."
            .. "\nThe code is written in the "
            .. vim.bo.ft
            .. " language:\n```\n"
    end
    table.insert(lines, 1, code_promptstring)
    table.remove(lines, 1)
    local prompt = table.concat(lines, "\n ")
    if is_code_review then
        prompt = prompt .. "\n```"
    end

    -- Chat command
    local chat = { "/usr/local/bin/chat", "-q", prompt }
    -- Set up virtual text
    local ns = vim.api.nvim_create_namespace("chat")
    local pos = vim.api.nvim_win_get_cursor(0)[1] - 1
    --local anim = require('significant')
    --anim.start_animated_sign(pos+1, 'dots4', 300)
    vim.api.nvim_buf_set_extmark(0, ns, pos, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor" } } })
    local oldbuf = vim.api.nvim_get_current_buf()
    -- Create new buffer in vsplit if not reviewing code
    if not is_code_review then
        vim.cmd("vsplit")
        vim.print("here1")
        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(buf, "AI Chat")
        vim.api.nvim_win_set_buf(win, buf)
        vim.print("here2")
        --anim.start_animated_sign(0, 'dots4', 300)
        vim.api.nvim_buf_set_extmark(
            buf,
            ns,
            0,
            0,
            { virt_text = { { " ■ AI engine is thinking...", "@constructor" } } }
        )
        -- Run chat command
        vim.print("here3")
        vim.fn.jobstart(chat, {
            stdout_buffered = false,
            on_stdout = function(_, data)
                vim.print("here4")
                vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
                vim.api.nvim_buf_clear_namespace(oldbuf, ns, 0, -1)
                vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
                --anim.stop_animated_sign(pos+1, {unplace_sign=true})
                vim.bo[buf].ft = buf_ft
            end,
        })
    else
        vim.fn.jobstart(chat, {
            stdout_buffered = true,
            on_stdout = function(_, data)
                --anim.stop_animated_sign(1, {unplace_sign=true})
                vim.api.nvim_buf_clear_namespace(oldbuf, ns, 0, -1)
                M.process_data(data)
            end,
        })
    end
end

-- General-porpuse chat prompting
vim.api.nvim_create_user_command("Chat", 'lua require("user.ai").run_chat("", "markdown")', { range = 2, bang = true })

-- Proofreading chat prompting
M.proofread = [[
	proofread the following content, keeping the syntax intact, and displaying nothing if content is not changed.
]]
vim.api.nvim_create_user_command(
    "ChatProofread",
    'lua require("user.ai").run_chat(require("user.ai").proofread, "markdown")',
    { range = 2, bang = true }
)

-- Code smell chat prompting
M.codesmell = [[You are an expert programmer who can review code for code quality and optimization.
Your output must be a single JSON array of top 5 code reviews and code smells with line numbers
and messages. Estimate the severity of each code review. Code reviews have to be bundled into
a single JSON array:
[{ "line": <line>, "severity": "LOW", "message": "<clear_review_message>", "lang": "<language>" }, ... more reviews ] ]]
vim.api.nvim_create_user_command(
    "ChatCodeSmell",
    'lua require("user.ai").run_chat(require("user.ai").codesmell, "json")',
    { range = 2, bang = true }
)
vim.api.nvim_create_user_command(
    "ChatOldCodeSmell",
    'lua require("user.ai").render_code_reviews(require("user.ai").code_reviews, vim.api.nvim_get_current_buf())',
    { range = 2, bang = true }
)

-- Diagnostics chat prompting

-- concatenate lines into a string
local function lines_as_string(buffnr, start_line, end_line)
    local lines = vim.api.nvim_buf_get_lines(buffnr, start_line - 1, end_line, false)
    return table.concat(lines, "\n")
end

-- get diagnostics for a range of lines
local function get_diagnostics(range_start, range_end)
    if range_end == nil then
        range_end = range_start
    end
    local diagnostics = {}
    for line_num = range_start, range_end do
        local line_diagnostics = vim.diagnostic.get(0, {
            lnum = line_num - 1,
            severity = { min = vim.diagnostic.severity.HINT },
        })
        if next(line_diagnostics) ~= nil then
            for _, diagnostic in ipairs(line_diagnostics) do
                table.insert(diagnostics, {
                    line_number = line_num,
                    message = diagnostic.message,
                    severity = vim.diagnostic.severity[diagnostic.severity],
                })
            end
        end
    end
    return diagnostics
end

-- Diagnostics chat prompting
M.run_diagnose = function()
    if check_chat() == nil then
        return nil
    end
    -- Back to normal mode
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")
    local start_line = vstart[2]
    local end_line = vend[2]
    local diagnostics = get_diagnostics(start_line, end_line)
    local lang = vim.bo[0].ft
    if next(diagnostics) == nil then
        local message = "No diagnostics found!"
        return message
    end
    local serializedDiagnostics = ""
    for i, diagnostic in ipairs(diagnostics) do
        serializedDiagnostics = serializedDiagnostics
            .. i
            .. ". Issue "
            .. i
            .. "\n\t- Location: Line "
            .. diagnostic.line_number
            .. "\n\t- Severity: "
            .. diagnostic.severity
            .. "\n\t- Message: "
            .. diagnostic.message
            .. "\n"
    end
    local context = lines_as_string(0, start_line, end_line)
    local prompt = "The programming language is "
        .. lang
        .. ".\n\n"
        .. "The following diagnostics were found:\n\n"
        .. serializedDiagnostics
        .. "\n\n"
        .. "This is the relevant code for context, which starts at line "
        .. start_line
        .. " :\n\n```\n"
        .. context
        .. "\n```"
    vim.notify("AI is thinking about diagnostics...", vim.log.levels.INFO)

    local prelude = [[
        You are an expert programmer who can help debug code diagnostics, such as warning and error messages.
        When appropriate, give solutions with code snippets as fenced codeblocks with a language identifier to enable syntax highlighting.
    ]]

    local chat = { "chat", "-q", prelude .. "\n" .. prompt }
    local ns = vim.api.nvim_create_namespace("chat")
    local pos = vim.api.nvim_win_get_cursor(0)[1] - 1
    vim.api.nvim_buf_set_extmark(0, ns, pos, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor" } } })
    local oldbuf = vim.api.nvim_get_current_buf()
    vim.cmd("vsplit")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf, "AI Chat")
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor" } } })
    vim.notify("AI is thinking about code reviews...", vim.log.levels.INFO)
    vim.fn.jobstart(chat, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
            vim.bo[buf].ft = "markdown"
            vim.api.nvim_buf_clear_namespace(oldbuf, ns, 0, -1)
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end,
    })
end

-- Diagnostics chat command
vim.api.nvim_create_user_command("ChatDiagnostics", 'lua require("user.ai").run_diagnose()', { range = 2, bang = true })

-- Code review

return M
