-- TODO: [WIP] similar code discovery
-- Working features:
-- - User inputs (concept + framework) for a code question. A specific function call is expected as output.
-- - AI agent guesses the appropriate function call and public repos are structurally searched for its usuage
-- Planned features:
-- - Similar code discovery for visual selection

local M = {}

local core = require("user.ai.core")
local options = require("user.ai.options")
local n = require("nui-components")

-- Cached input for code discovery
M.input = {
	ask = "",
	framework = "",
	last_search = "",
}

-- get user input for code discovery
-- @param callback function to be called after user input is received
M._get_user_input = function(callback)
	local renderer = n.create_renderer({
		width = 80,
		height = 20,
	})
	local body = function()
		-- Define variables to hold references to the form inputs
		local question
		local framework
		return n.form(
			{
				id = "discover_form",
				submit_key = "<C-t>",
				on_submit = function(is_valid)
					if not is_valid then
						return nil
					end
					M.input.ask = question
					M.input.framework = framework
					renderer:close()
					callback()
				end,
			},
			n.paragraph({
				lines = {
					n.line(
						n.text("<Tab>", "String"),
						" to move between fields, ",
						n.text("<C-t>", "String"),
						" to submit"
					),
				},
				align = "left",
			}),
			n.text_input({
				autofocus = true,
				autoresize = true,
				flex = 1,
				border_label = "How do I ...?",
				max_lines = 8,
				validate = n.validator.min_length(10),
				placeholder = "sum a variable from all parallel processors",
				on_change = function(value, _)
					question = value
				end,
			}),
			n.text_input({
				max_lines = 1,
				border_label = "Framework or language",
				placeholder = "OpenFOAM",
				validate = n.validator.min_length(3),
				on_change = function(value, _)
					framework = value
				end,
			})
		)
	end
	renderer:render(body())
end

-- search public repos for code that might do what the user asked
-- @param run_ai: boolean: should the AI agent be consulted
M.chat_code_discover = function(run_ai)
	if not run_ai then
		vim.cmd("SourcegraphSearch " .. M.last_search)
		return nil
	end
	M._get_user_input(function()
		-- add system prompt to the code_args
		local sysprompt = "You are a senior "
			.. M.input.framework
			.. " developer. Respond only in code, absolutely no explanation."
		if vim.list_contains(options.discover.code_args, "-preprompt") then
			local idx = vim.tbl_indexof(options.discover.code_args, "-preprompt")
			options.discover.code_args[idx + 1] = sysprompt
		else
			vim.list_extend(options.discover.code_args, {
				"-preprompt",
				"You are a senior "
					.. M.input.framework
					.. " developer. Respond only in code, absolutely no explanation.",
			})
		end
		-- construct the user prompt
		local prm = [[How do I ]]
			.. M.input.ask
			.. [[ in ]]
			.. M.input.framework
			.. [[. Your response must be parseable JSON of a syntax tree of the format:
            ```
            {
            "expression": {
                "type": "call_expression",
                "callee":{
                    "type":"identifier",
                    "name":"<function_name>"
                },
                arguments:[
                    {"type":"identifier", "name":"param0"}, ...
                ],
            }
            }
            ```
            where arguments can be identifiers or call expressions themselves. Provide no explanation or context]]
		local parser = function(parsed_data)
			local function _parse_call(expr)
				local search_query = expr.callee.name .. "("
				for i, arg in ipairs(expr.arguments) do
					if i > 1 then
						search_query = search_query .. ","
					end
					if arg.type == "call_expression" and not string.find(arg.callee.name, "operator") then
						search_query = search_query .. _parse_call(arg)
					else
						search_query = search_query .. "..."
					end
				end
				return search_query .. ")"
			end
			if parsed_data.expression.type ~= "call_expression" then
				return nil
			end
			local search_query = _parse_call(parsed_data.expression)
			M.last_search = search_query .. " patternType:structural repo:" .. M.input.framework .. "@*refs/heads/*"
			vim.notify('Sourcegraph: Searching for "' .. M.last_search .. '"', vim.log.levels.INFO)
			vim.cmd("SourcegraphSearch " .. M.last_search)
		end
		core.chat_code_command("discover", function()
			return prm
		end, parser, function() end, function() end)
	end)
end

return M
