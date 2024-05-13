local M = {}

local core = require("user.ai.core")
local options = require("user.ai.options")

-- prompt for code reviewing
M.code_reviews_prompt = function()
	local prm = [[Write a JSON file of top ]]
		.. options.review.count
		.. [[ code reviews for the following code snippet.]]
		.. [[ Your reviewing should focus on ]]
		.. options.review.focus
		.. [[ aspects.]]
		.. [[ Your output must be a parsable JSON with no code fences around it. My code is written in the ]]
		.. vim.bo[0].ft
		.. [[ language. Your JSON should contain an array of objects
    of the following format: { "line": <line>, "severity": "LOW", "message": "<clear_review_message>", "edit": { new = "<new_text>", range = {start = { line = "<num>", character = "<num>"}, end = { line = "<num>", character = "<num>"}}}, "lang": "<language>" }.
    Line numbers are indicated at the start of each line by the format `@<line>@`. The text edits must be accurate with range line and character positions.]]
	return core.build_prompt(prm)
end

-- focus for code reviewing
M.pick_review_focus = function()
    core.pick_style({
        "Code quality",
        "Code style",
        "Code structure",
        "Code performance",
        "Code security",
        "Code readability",
        "Code maintainability",
        "Code complexity",
        "Code testing",
        "Code refactoring",
        "Code optimization",
        "Code best practices",
        "Code patterns",
        "Code anti-patterns",
        "Code smells",
        "Code bugs",
        "Code suggestions",
        "Code improvements",
        "Code enhancements",
        "No particular", -- default
    }, "Pick code review focus", "review")
end

-- buffer code reviews
M.code_reviews = {}

-- preview code review suggestions
M.preview_code_review = function()
	core.preview_edits(options.review.edit, M.code_reviews)
end

-- Inserts review suggestions into M.code_reviews for previewing
M.chat_code_review = function()
	local parser = function(parsed_data)
		if parsed_data ~= nil then
			for _, entry in ipairs(parsed_data) do
                if entry.edit.range["start"].line == entry.edit.range["end"].line
                and entry.edit.range["start"].character == 0
                and entry.edit.range["end"].character == 0 then
                    entry.edit.new = entry.edit.new .. "\n"
                end
				local diagnostic = {
					source = options.source,
					code = nil,
					lnum = entry.line - 1,
					col = 0,
					severity = core.to_vim_severity(entry.severity),
					message = entry.message,
					edit = entry.edit,
				}
                vim.list_extend(M.code_reviews, {diagnostic})
			end
		else
			vim.notify("Response from AI agent didn't adhere to expected structure.", vim.log.levels.WARN)
		end
	end
    -- set provider to phind, works better for reviewer
	core.chat_code_command(
		"review",
		M.code_reviews_prompt,
        parser,
		function(ns)
            vim.diagnostic.set(ns, 0, M.code_reviews)
		end,
		M.preview_code_review
	)
end

return M
