-- replacing telescope-git-file-history because it used vim-fugitive plugin
local has_telescope, _ = pcall(require, "telescope")
if not has_telescope then return end

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local Job = require("plenary.job")

M = {}
M.config = function() end

if not has_telescope then
    M.git_file_history = function() end
    return M
end

local layout_ops = require("user.telescope").layout_ops

M.git_file_history = function()
    local file = vim.fn.expand("%")
    if file == "" then return end

    -- Capture filetype from current buffer before opening picker
    local ft = vim.bo.filetype

    Job:new({
        command = "git",
        args = { "log", "--pretty=format:%h %ad %s", "--date=short", "--", file },
        cwd = vim.fn.getcwd(),
        on_exit = vim.schedule_wrap(function(j, return_val)
            local commits = j:result()
            if #commits == 0 then
                print("No git history found for file:", file)
                return
            end

            pickers.new({}, {
                prompt_title = "Git File History",
                finder = finders.new_table {
                    results = commits,
                    entry_maker = function(entry)
                        local _, date, msg = entry:match("^(%S+)%s+(%S+)%s+(.*)$")
                        return {
                            value = entry,
                            display = function()
                                return string.format("%s %s", date, msg), {
                                    { { 0, #date }, "TelescopePreviewDate" },
                                    { { #date + 1, #date + #msg + 1 }, "TelescopeResultsMethod" },
                                }
                            end,
                            ordinal = entry,
                        }
                    end,
                },
                sorter = conf.generic_sorter({}),
                previewer = previewers.new_buffer_previewer {
                    define_preview = function(self, entry, status)
                        local commit_hash = entry.value:match("^(%S+)")

                        -- Get file content at this commit
                        local content = vim.fn.systemlist("git show " .. commit_hash .. ":" .. file)
                        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, content)
                        vim.bo[self.state.bufnr].filetype = ft
                        vim.bo[self.state.bufnr].modifiable = false

                        -- Get diff between parent and this commit
                        local diff = vim.fn.systemlist("git diff " .. commit_hash .. "^.." .. commit_hash .. " -- " .. file)
                        local ns_id = vim.api.nvim_create_namespace("git_file_history_diff")
                        vim.api.nvim_buf_clear_namespace(self.state.bufnr, ns_id, 0, -1)

                        -- Parse diff and apply highlights
                        local new_line = 0
                        local removed_lines = {}

                        for _, line in ipairs(diff) do
                            if line:match("^@@") then
                                -- Extract line numbers from @@ -old_start,old_count +new_start,new_count @@
                                new_line = tonumber(line:match("%+(%d+)")) - 1
                            elseif line:match("^%+") and not line:match("^%+%+%+") then
                                -- Added line in this commit
                                vim.api.nvim_buf_add_highlight(self.state.bufnr, ns_id, "DiffAdd", new_line, 0, -1)
                                new_line = new_line + 1
                            elseif line:match("^%-") and not line:match("^%-%-%-") then
                                -- Removed line - store for virtual text
                                table.insert(removed_lines, {line = new_line, text = line:sub(2)})
                            else
                                -- Context line
                                if not line:match("^diff") and not line:match("^index") and not line:match("^ ") then
                                    -- Skip non-content lines
                                elseif line:match("^ ") then
                                    new_line = new_line + 1
                                end
                            end
                        end

                        -- Add virtual text for removed lines
                        for _, removed in ipairs(removed_lines) do
                            if removed.line >= 0 and removed.line < vim.api.nvim_buf_line_count(self.state.bufnr) then
                                vim.api.nvim_buf_set_extmark(self.state.bufnr, ns_id, removed.line, 0, {
                                    virt_lines = {{{"- " .. removed.text, "DiffDelete"}}},
                                    virt_lines_above = true,
                                })
                            end
                        end
                    end,
                },
                layout_config = layout_ops.layout_config,
                layout_strategy = layout_ops.layout_strategy,
                attach_mappings = function(prompt_bufnr, map)
                    map("i", "<CR>", function()
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        local commit_hash = selection.value:match("^(%S+)")
                        vim.cmd("e +" .. commit_hash .. " " .. file)
                    end)
                    return true
                end,
            }):find()
        end),
    }):start()
end

return M
