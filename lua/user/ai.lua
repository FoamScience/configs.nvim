-- A small Lua script to run LLM-based AI assistants on Neovim Buffers

local function checkChat()
    if vim.fn.executable('chat') == 0 then
        vim.notify([[chat command not found; a GPT-like CMD tool is required that can run
        --`chat -q <prompt>` and write results to stdout.]], vim.log.levels.WARN)
        return nil
    end
end

local M = {}

local function len(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- Generic Chat prompting

M.RunChat = function(promptstring)
    if checkChat() == nil then return nil end
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")
    local line_start = vstart[2]
    local line_end = vend[2]
    local lines = vim.fn.getline(line_start,line_end)
    table.insert(lines, 1, promptstring)
    local prompt = table.concat(lines, "\n")
    local chat = {"chat", "-q", prompt}
    local ns = vim.api.nvim_create_namespace("chat")
    local pos = vim.api.nvim_win_get_cursor(0)[1]-1
    vim.api.nvim_buf_set_extmark(0, ns, pos, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor"} }})
    local oldbuf = vim.api.nvim_get_current_buf()
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor"} }})
    vim.fn.jobstart(chat, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            local row = vend[2]
            vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
            vim.api.nvim_buf_clear_namespace(oldbuf, ns, 0, -1)
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end
    })
end

vim.api.nvim_create_user_command('Chat', 'lua require("user.ai").RunChat("")', { range = 2, bang = true})
M.proofread = "proofread the following content, keeping the syntax intact, and displaying nothing if content is not changed"
vim.api.nvim_create_user_command('ChatProofread', 'lua require("user.ai").RunChat(require("user.ai").proofread)', { range = 2, bang = true})

-- Diagnostics chat prompting

local function lines_as_string(buffnr, start_line, end_line)
    local lines = vim.api.nvim_buf_get_lines(buffnr, start_line-1, end_line, false)
    return table.concat(lines, "\n")
end

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

M.RunDiagnose = function()
    if checkChat() == nil then return nil end
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
    local prompt = "The programming language is " .. lang .. ".\n\n"
        .. "The following diagnostics were found:\n\n"
        .. serializedDiagnostics
        .. "\n\n"
        .. "This is the relevant code for context, which starts at line "
        .. start_line .. " :\n\n```\n"
        .. context .. "\n```"
    vim.notify("AI is thinking about diagnostics...", vim.log.levels.INFO)

    local prelude = [[
        You are an expert programmer who can help debug code diagnostics, such as warning and error messages.
        When appropriate, give solutions with code snippets as fenced codeblocks with a language identifier to enable syntax highlighting.
    ]]
    
    local chat = {"chat", "-q", prelude .. "\n" .. prompt}
    local ns = vim.api.nvim_create_namespace("chat")
    local pos = vim.api.nvim_win_get_cursor(0)[1]-1
    vim.api.nvim_buf_set_extmark(0, ns, pos, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor"} }})
    local oldbuf = vim.api.nvim_get_current_buf()
    vim.cmd('vsplit')
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor"} }})
    vim.fn.jobstart(chat, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
            vim.bo[buf].ft = "markdown"
            vim.api.nvim_buf_clear_namespace(oldbuf, ns, 0, -1)
            vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        end
    })
end

vim.api.nvim_create_user_command('ChatDiagnostics', 'lua require("user.ai").RunDiagnose()', { range = 2, bang = true})

return M
