-- A small Lua script to run LLM-based AI assistants on Neovim Buffers
if vim.fn.executable('chat') == 0 then
    print("chat command not found; visit: https://github.com/aandrew-me/tgpt")
    return nil
end
local M = {}
local function len(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

M.RunChat = function()
    local vstart = vim.fn.getpos("'<")
    local vend = vim.fn.getpos("'>")
    local line_start = vstart[2]
    local line_end = vend[2]
    local lines = vim.fn.getline(line_start,line_end)
    local prompt = table.concat(lines, "\n")
    local chat = {"chat", "-q", prompt}
    local ns = vim.api.nvim_create_namespace("chat")
    local pos = vim.api.nvim_win_get_cursor(0)[1]-1
    vim.api.nvim_buf_set_extmark(0, ns, pos, 0, { virt_text = { { " ■ AI engine is thinking...", "@constructor"} }})
    vim.fn.jobstart(chat, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            local row = vend[2]
            vim.api.nvim_buf_set_lines(0, row, row, false, {">>>>> AI Response:"})
            vim.api.nvim_buf_set_lines(0, row+1, row+1, false, data)
            vim.api.nvim_buf_set_lines(0, row+1+len(data), row+1+len(data), false, {"<<<<< End of AI Response"})
            vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
        end
    })
end

vim.api.nvim_create_user_command('Chat', 'lua require("user.ai").RunChat()', { range = 2, bang = true})

return M
