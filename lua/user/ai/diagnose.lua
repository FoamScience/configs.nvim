local M = {}

local core = require("user.ai.core")
local options = require("user.ai.options")

M._get_selection_diagnostics = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local start_mark = vim.fn.getpos("'<")
    local end_mark = vim.fn.getpos("'>")
    local diagnostics = vim.diagnostic.get(bufnr)
    local diag_msg = "\n"
    for _, diagnostic in ipairs(diagnostics) do
        if diagnostic.lnum >= start_mark[2]-1 and diagnostic.lnum + 1 <= end_mark[2]-1 then
            diag_msg = diag_msg
                .. string.format(
                    "[[ @%d@ %s(%s): %s ]]\n",
                    diagnostic.lnum + 1,
                    diagnostic.code,
                    diagnostic.source,
                    diagnostic.message
                )
        end
    end
    return diag_msg
end

-- prompt for diagnostics resolving
M.code_fixes_prompt = function()
    local prm = [[Write a JSON file of code fixes for the following code diagnsotics.]]
        .. [[ Your output must be a parsable JSON with no code fences around it. My code is written in the ]]
        .. vim.bo[0].ft
        .. [[ language. Your JSON should contain an array of objects
    of the following format: { "line": <line>, "severity": "LOW_or_MEDIUM_or_HIGH", "source": "<lsp_server_or_linter>", "message": "<clear_how_to_fix_message>", "edit": { new = "<new_text>", range = {start = { line = "<num>", character = "<num>"}, end = { line = "<num>", character = "<num>"}}}, "lang": "<language>" }.
    Line numbers are indicated at the start of each line by the format `@<line>@`. The text edits should follow LSP convention and be accurate with line and character positions following original code content, even for milti-line edits.
    Report code edits as whole lines edits. Here are the diagnostics:]]
        .. M._get_selection_diagnostics()
    return core.build_prompt(prm)
end

-- buffer code fixes
M.code_fixes = {}

-- preview code fixes
M.preview_code_fixes = function()
	core.preview_edits(options.diagnose.edit, M.code_fixes)
end

-- Inserts fix suggestions into M.code_fixes for previewing
M.chat_code_fix = function()
	local parser = function(parsed_data)
		if parsed_data ~= nil then
			for _, entry in ipairs(parsed_data) do
                -- TODO: this needs a bit more testing
                entry.edit.range.start.character = 0
				local diagnostic = {
					source = options.source,
					code = nil,
					lnum = entry.line - 1,
					col = 0,
					severity = core.to_vim_severity(entry.severity),
					message = "(".. entry.source .. "): " .. entry.message,
					edit = entry.edit,
				}
                M.code_fixes = vim.tbl_extend("force", M.code_fixes, {diagnostic})
			end
		else
			vim.notify("Response from AI agent didn't adhere to expected structure.", vim.log.levels.WARN)
		end
	end
	core.chat_code_command(
		"diagnose",
		M.code_fixes_prompt,
        parser,
		function(ns)
            vim.diagnostic.set(ns, 0, M.code_fixes)
		end,
		M.preview_code_fixes
	)
end

return M
