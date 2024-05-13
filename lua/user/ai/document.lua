local M = {}

local core = require("user.ai.core")
local options = require("user.ai.options")

-- prompt for code documentation
M.code_docs_prompt = function()
	local prm = [[Write a JSON file of top 3 code documentation suggestions for the following code snippet.]]
		.. [[ Your documentation style should resemble ]]
		.. options.document.style
		.. [[. Your output must be a parsable JSON with no code fences around it. My code is written in the ]]
		.. vim.bo[0].ft
		.. [[ language. Your JSON should contain an array of objects
    of the following format: { { value = "<docs_suggestion_1>" }, { value = "<docs_suggestion_1>"}, ... }.
    Line numbers are indicated at the start of each line by the format `@<line>@` and should be ignored.]]
		.. [[ dont include any code line from the snippet. each suggestion needs to be a comment.]]
	return core.build_prompt(prm)
end

-- buffer code docs
M.code_docs = {}

-- preview code documentation suggestions
M.preview_code_document = function()
	core.preview_edits(options.document.edit, M.code_docs)
end

-- Inserts documentation into M.code_docs for previewing
M.chat_code_document = function()
	local parser = function(parsed_data)
		for _, entry in ipairs(parsed_data) do
			local doc = {
				edit = {
					new = entry.value,
					newText = entry.value,
					range = {
						start = { line = vim.fn.getpos("'<")[2], character = 0 },
						["end"] = { line = vim.fn.getpos("'<")[2], character = 0 },
					},
				},
				message = entry.value,
			}
			vim.list_extend(M.code_docs, { doc })
		end
	end
	core.chat_code_command(
		"document",
		M.code_docs_prompt, -- how to build the prompt
		parser, -- how to parse AI output
		function()
			return nil
		end, -- no diagnostics
		M.preview_code_document -- preview the edits if edits are on
	)
end

return M
