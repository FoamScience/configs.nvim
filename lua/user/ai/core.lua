local M = {}

local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local anim = require("significant")
local options = require("user.ai.options")

-- check availably of tgpt cmd
M.check_tgpt = function()
    if vim.fn.executable("tgpt") == 0 then
        vim.notify(
            [[tgpt command not found; a GPT-like CMD tool is required that can run
            `tgpt -q <prompt>` and write results to stdout.
            For example: https://github.com/aandrew-me/tgpt]],
            vim.log.levels.ERROR
        )
        return nil
    end
    return true
end

-- get selected lines from buffer with line numbers
-- encoded as @<line_number>@ at the beginning of each line
M.get_selected_lines = function()
    local start_line = vim.api.nvim_buf_get_mark(0, "<")[1]
    local end_line = vim.api.nvim_buf_get_mark(0, ">")[1]
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    for i, line in ipairs(lines) do
        lines[i] = string.format("@%d@ %s", start_line + i - 1, line)
    end
    local lines_str = table.concat(lines, "\n")
    return lines_str:gsub('"', '\\"')
end

-- build the full prompt for AI command
-- @param prompt: string: the task part of the prompt
M.build_prompt = function(prompt)
    local lang = vim.bo[0].ft
    return prompt .. "\n```" .. lang .. "\n" .. M.get_selected_lines() .. "\n```"
end

-- convert AI response to diagnostics severity
M.to_vim_severity = function(severity)
    if severity == "LOW" then
        return vim.diagnostic.severity.HINT
    elseif severity == "MEDIUM" then
        return vim.diagnostic.severity.WARN
    elseif severity == "HIGH" then
        return vim.diagnostic.severity.ERROR
    else
        return vim.diagnostic.severity.WARN
    end
end

-- run tgpt command asynchronously
-- @param command: string: the command to run
-- @param args: table: the arguments to pass to the command
-- @param callback: function: the function to call with the results
M._run_async_command = function(command, args, callback)
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)
    local output_buffer = {}
    local handle, pid
    handle, pid = vim.loop.spawn(command, {
        args = args,
        stdio = { nil, stdout, stderr },
    }, function(code, signal)
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        handle:close()
        callback(code, signal, table.concat(output_buffer))
    end)
    if handle then
        stdout:read_start(function(err, data)
            assert(not err, err)
            if data then
                table.insert(output_buffer, data)
            end
        end)
        stderr:read_start(function(err, data)
            assert(not err, err)
            if data then
                -- Handle stderr data if needed
                vim.print("Error running " .. command .. " command:", data)
            end
        end)
    else
        vim.print("Failed to spawn " .. command .. " process")
    end
end

-- get number of leading whitespace characters in a string
M.find_first_non_whitespace = function(line)
    local index = 1
    for char in line:gmatch(".") do
        if not char:match("%s") then
            return index
        end
        index = index + 1
    end
    return nil
end

-- pick a style from a list of options
-- @param opts: table: the list of options (strings)
-- @param prompt_title: string: the title of the prompt
-- @param label: string: the label of the core.options[label].style to set
M.pick_style = function(opts, prompt_title, label)
    local original_buf = vim.api.nvim_win_get_buf(0)
    pickers
        .new({}, {
            prompt_title = prompt_title,
            finder = finders.new_table({
                results = opts,
                entry_maker = function(entry)
                    return {
                        display = entry,
                        value = entry,
                        ordinal = entry,
                        bufnr = original_buf,
                    }
                end,
            }),
            sorter = sorters.get_generic_fuzzy_sorter(),
            attach_mappings = function(prompt_bufnr)
                -- TODO: handle multiple selections through telescope?
                actions.select_default:replace(function()
                    local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
                    if selection then
                        options[label].style = selection.value
                    end
                    actions.close(prompt_bufnr)
                end)
                return true
            end,
        })
        :find()
end

-- create text edit previews
-- @param bufnr: number: the buffer number
-- @param preview_bufnr: number: the preview buffer number
-- @param entry: table: the text edit entry
M.text_edits_preview_maker = function(bufnr, preview_bufnr, entry)
    -- TODO: get context lines with tree-sitter?
    local num_lines = math.max(math.floor((vim.api.nvim_win_get_height(0) - #entry.value.newText) / 2), 10)
    local lines_before =
        vim.api.nvim_buf_get_lines(bufnr, entry.value.range.start.line - num_lines, entry.value.range.start.line, false)
    local old_content =
        vim.api.nvim_buf_get_lines(bufnr, entry.value.range.start.line, entry.value.range["end"].line + 1, false)
    local padding = M.find_first_non_whitespace(old_content[1])
    local new_edit_text = {}
    for line in entry.value.newText:gmatch("[^\r\n]+") do
        if M.find_first_non_whitespace(line) ~= padding-1 then
            table.insert(new_edit_text, string.rep(" ", padding-1) .. line)
        end
    end
    local lines_after = vim.api.nvim_buf_get_lines(
        bufnr,
        entry.value.range.start.line + 1,
        entry.value.range.start.line + num_lines,
        false
    )
    local is_line_insertion = false
    if
        entry.value.range.start.character == 0
        and entry.value.range["end"].character == 0
        and entry.value.range.start.line == entry.value.range["end"].line
    then
        is_line_insertion = true
    end

    local commentstring = vim.bo[bufnr].commentstring

    local display = {}
    for _, line in ipairs(lines_before) do
        table.insert(display, line)
    end
    local was = commentstring:gsub("%%s", " " .. string.rep(">", padding) .. ">>> WAS ")
    was = string.rep(" ", padding - 1) .. was
    table.insert(display, was)
    for _, line in ipairs(old_content) do
        table.insert(display, line)
    end
    local becomes = commentstring:gsub("%%s", " " .. string.rep("<", padding) .. "<<< WILL BECOME ")
    becomes = string.rep(" ", padding - 1) .. becomes
    table.insert(display, becomes)
    for _, line in ipairs(new_edit_text) do
        if line ~= nil and line ~= "" then
            table.insert(display, line)
        end
    end
    if is_line_insertion then
        for _, line in ipairs(old_content) do
            table.insert(display, line)
        end
    end
    local ending = commentstring:gsub("%%s", " " .. string.rep(">", padding + 3) .. " ")
    ending = string.rep(" ", padding - 1) .. ending
    table.insert(display, ending)
    for _, line in ipairs(lines_after) do
        table.insert(display, line)
    end

    return display
end

-- Telescope previewer for text edits
M.text_edits_previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry, status)
        local bufnr = entry.bufnr
        local preview_bufnr = self.state.bufnr
        local lines = M.text_edits_preview_maker(bufnr, preview_bufnr, entry)
        vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, lines)
        vim.bo[preview_bufnr].filetype = vim.bo[bufnr].filetype
    end,
})

-- pick a text edit from a list of text edits
-- @param text_edits: table: the list of text edits in LSP format
M.pick_text_edits = function(text_edits)
    local original_buf = vim.api.nvim_win_get_buf(0)
    local winid = vim.api.nvim_get_current_win()
    pickers
        .new({}, {
            prompt_title = "Select a Text Edit",
            finder = finders.new_table({
                results = text_edits,
                entry_maker = function(entry)
                    return {
                        display = entry.display:gsub("\n",""),
                        value = entry,
                        ordinal = entry.newText,
                        bufnr = original_buf,
                    }
                end,
            }),
            previewer = M.text_edits_previewer,
            sorter = sorters.get_generic_fuzzy_sorter(),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
                    if selection then
                        vim.lsp.util.apply_text_edits({ selection.value }, original_buf, vim.bo.fileencoding)
                        local range = selection.value.range
                        local line = range.start.line + 1
                        local col = range.start.character
                        vim.api.nvim_win_set_cursor(winid, { line, col })
                        vim.api.nvim_buf_clear_namespace(0, original_buf, line, line)
                    end
                    actions.close(prompt_bufnr)
                end)
                return true
            end,
        })
        :find()
end

-- look at the edits in Telescope
-- @param edit: boolean: whether to apply the to-be-selected edit
-- @param source: table: JSON table from AI
M.preview_edits = function(edit, source)
    local lsp_edits = {}
    if not edit then
        return nil
    end
    if source == nil or vim.tbl_isempty(source) then
        vim.notify("No edits to preview", vim.log.levels.INFO)
        return nil
    end
    for _, entry in ipairs(source) do
        -- TODO: better way to get correct starting character position?
        if entry.edit == vim.NIL then
            goto continue
        end
        if entry.edit.range.start.character == 0 and entry.edit.range["end"].character ~= 0 then
            local line_contents = vim.fn.getline(entry.edit.range.start.line)
            entry.edit.range.start.character = M.find_first_non_whitespace(line_contents) - 1
            entry.edit.range["end"].character = #line_contents
        end
        local lsp_edit = {
            range = {
                start = {
                    line = entry.edit.range.start.line - 1,
                    character = entry.edit.range.start.character,
                },
                ["end"] = {
                    line = entry.edit.range["end"].line - 1,
                    character = entry.edit.range["end"].character,
                },
            },
            newText = (entry.edit.newText or entry.edit.new),
            display = entry.message,
        }
        if
            lsp_edit.range.start.character == 0
            and lsp_edit.range["end"].character == 0
            and lsp_edit.range.start.line == lsp_edit.range["end"].line
        then
            local line_contents = vim.fn.getline(entry.edit.range.start.line)
            local padding = M.find_first_non_whitespace(line_contents) - 1
            lsp_edit.newText = string.rep(" ", padding) .. lsp_edit.newText
        end
        table.insert(lsp_edits, lsp_edit)
        ::continue::
    end
    if #lsp_edits == 0 then
        vim.notify("No edits to preview", vim.log.levels.INFO)
        return nil
    end
    M.pick_text_edits(lsp_edits)
end

-- run a specific AI command
-- @param: label: string: name of the command to run
-- @param: command_prompt: function: the function to get the prompt
-- @param: parser: function: the function to parse the AI response
-- @param: diagnoser: function: the function to set LSP diagnostics
-- @param: preview: function: the function to preview the edits
M.chat_code_command = function(label, command_prompt, parser, diagnoser, preview)
    M.check_tgpt()
    local prompt = command_prompt()
    local args = vim.list_extend({}, options[label].code_args)
    vim.list_extend(args, options.code_args)
    table.insert(args, prompt)
    vim.api.nvim_buf_clear_namespace(0, 0, 0, -1)
    local ns = vim.api.nvim_create_namespace("chat_" .. label)
    local strt = vim.api.nvim_win_get_cursor(0)[1]-1
    local pos = vim.fn.getpos("'<")
    if pos[1] ~= 0 or pos[2] ~= 0 then
        strt = vim.fn.getpos("'<")[2] - 1
    end
    vim.api.nvim_buf_set_extmark(
        0,
        ns,
        strt,
        0,
        { virt_text = { { " ■ AI engine trying to " .. label .. "...", "@constructor" } } }
    )
    anim.start_animated_sign(strt + 1, (options[label].sign or "dots8"), 300)
    M._run_async_command(options.cmd, args, function(code, signal, stdout_buffer)
        vim.schedule(function()
            stdout_buffer = stdout_buffer:gsub("^```json\n(.*)\n```$", "%1")
            stdout_buffer = stdout_buffer:gsub("^`(.*)`$", "%1")
            local success, parsed_data = pcall(vim.json.decode, stdout_buffer)
            if success then
                parser(parsed_data)
            else
                vim.notify("Response from AI agent didn't adhere to expected JSON structure.", vim.log.levels.WARN)
                parser(stdout_buffer)
            end
            anim.stop_animated_sign(strt + 1, { unplace_sign = true })
            vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
            diagnoser(ns)
            preview()
        end)
    end)
end

return M
