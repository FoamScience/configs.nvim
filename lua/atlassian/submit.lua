--- Shared submit registry for Atlassian edit buffers.
--- Makes :w a local-only save; <leader>ss triggers the remote API call.
local M = {}

---@class SubmitEntry
---@field submit fun() The callback that performs the remote API call
---@field label string Display label for winbar (e.g. "Jira Comment")

---@type table<number, SubmitEntry>
local registry = {}

--- Register a buffer as submittable.
---@param buf number Buffer handle
---@param opts { submit: fun(), label?: string }
function M.register(buf, opts)
    registry[buf] = {
        submit = opts.submit,
        label = opts.label or "Atlassian",
    }

    -- BufWriteCmd: local-only save (just clear modified flag)
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        buffer = buf,
        callback = function()
            vim.bo[buf].modified = false
        end,
    })

    -- <leader>ss: submit to remote
    vim.keymap.set("n", "<leader>ss", function()
        M.submit(buf)
    end, { buffer = buf, desc = "Submit to " .. (opts.label or "remote") })

    -- Winbar indicator
    local label = opts.label or "Atlassian"
    vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
        buffer = buf,
        callback = function()
            local wins = vim.fn.win_findbuf(buf)
            for _, w in ipairs(wins) do
                vim.wo[w].winbar = " DRAFT  " .. label .. "  %=  <leader>ss to submit "
            end
        end,
    })
    -- Set immediately for the current window
    local wins = vim.fn.win_findbuf(buf)
    for _, w in ipairs(wins) do
        vim.wo[w].winbar = " DRAFT  " .. label .. "  %=  <leader>ss to submit "
    end

    -- Cleanup on buffer wipe
    vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
            registry[buf] = nil
        end,
    })
end

--- Submit the buffer to the remote.
---@param buf? number Buffer handle (defaults to current)
function M.submit(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local entry = registry[buf]
    if not entry then
        vim.notify("No submit handler registered for this buffer", vim.log.levels.WARN)
        return
    end
    entry.submit()
end

-- User command for discoverability
vim.api.nvim_create_user_command("AtlassianSubmit", function()
    M.submit()
end, { desc = "Submit current buffer to Atlassian remote" })

return M
