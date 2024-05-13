-- TODO: [WIP] still a little bit messy with a lot of reused code
local M = {}

local n = require("nui-components")
local core = require("user.ai.core")
local options = require("user.ai.options")
local gitsigns = require("gitsigns")
local pickers = require("telescope.pickers")
local actions = require("telescope.actions")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local previewers = require("telescope.previewers")

-- buffer commit messages and diffs
M.commitmsgs = {}
M.commitdiffs = {}

M.input = {
	ask = "",
	framework = "",
}

-- custom previewer for git diffs in a Markdown fashion
local diffs_previewer = previewers.new_buffer_previewer({
	define_preview = function(self, entry, status)
		local preview_bufnr = self.state.bufnr
		local lines = {}
		local v = entry.value
		table.insert(lines, string.format("Repo: [%s][]", v.repository.name))
		table.insert(lines, string.format("Commit Hash: %s", v.commit.oid))
		table.insert(lines, string.format("Commit Author: %s (%s)", v.author, v.date))
		table.insert(lines, string.format("Commit Msg: %s", v.commit.subject))
		local url = "https://" .. v.commit.url
		table.insert(lines, string.format("Commit URL: [%s](%s)", url, url))
		local diffs = vim.split(v.diffPreview, "\n")
		table.insert(lines, "Diffs:")
		table.insert(lines, "```diff")
		for _, diff in ipairs(diffs) do
			table.insert(lines, diff)
		end
		table.insert(lines, "```")
		vim.api.nvim_buf_set_lines(preview_bufnr, 0, -1, false, lines)
		vim.bo[preview_bufnr].filetype = "markdown"
	end,
})

-- telescope picker for commit diffs
local diffs_picker = function()
	pickers
		.new({}, {
			prompt_title = "Select a Commit Diff",
			finder = finders.new_table({
				results = M.commitdiffs,
				entry_maker = function(entry)
					return {
						display = entry.subject .. " | " .. entry.author,
						value = entry,
						ordinal = entry.subject,
					}
				end,
			}),
			sorter = sorters.get_generic_fuzzy_sorter(),
			previewer = diffs_previewer,
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
					if selection then
						vim.fn.setreg("+", "https://sourcegraph.com" .. selection.value.url)
						vim.notify("Copied commit msg to +reg: https://sourcegraph.com" .. selection.value.url)
					end
					actions.close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

-- search for commit diffs using sourcegraph
-- this is a placeholder for the same feature in sg.nvim (not yet implemented)
local diffs_search = function(input)
	local graphqlQuery = [[
query ($query: String!) {
  search(query: $query, version: V2) {
    results {
      results {
        __typename
        ... on CommitSearchResult {
          ...CommitSearchResultFields
        }
      }
    }
  }
}

fragment CommitSearchResultFields on CommitSearchResult {
  messagePreview {
    value
  }
  diffPreview {
    value
  }
  url
  commit {
    repository {
      name
    }
    oid
    url
    subject
    author {
      date
      person {
        displayName
      }
    }
  }
}
]]
	local graphqlEndpoint = "https://sourcegraph.com/.api/graphql"
	local accessToken = require("sg.auth").get().token
	local queryVariables = {
		query = string.format("%s type:diff repo:%s", input, M.input.framework),
	}
	local payload = {
		query = graphqlQuery,
		variables = queryVariables,
	}
	local payloadJSON = vim.fn.json_encode(payload)

	-- Construct the command to execute
	local cmd = "curl"
	local args = {
		"-s",
		"-X",
		"POST",
		"-H",
		"Authorization: token " .. accessToken,
		"-H",
		"Content-Type: application/json",
		"-d",
		payloadJSON,
		graphqlEndpoint,
	}
	core._run_async_command(cmd, args, function(code, signal, stdout_buffer)
		vim.schedule(function()
			local success, parsed_data = pcall(vim.json.decode, stdout_buffer)
			if not success then
				vim.notify("Response from sourcegraph didn't adhere to expected JSON structure.", vim.log.levels.WARN)
				return nil
			end
			local results = parsed_data.data.search.results.results
			for _, result in ipairs(results) do
				vim.list_extend(M.commitdiffs, {
					{
						commit = result.commit,
						repository = result.commit.repository,
						diffPreview = result.diffPreview.value,
						url = result.commit.url,
						date = result.commit.author.date,
						author = result.commit.author.person.displayName,
						subject = result.commit.subject,
					},
				})
			end
			diffs_picker()
		end)
	end)
end

-- compute current diffs (for commit msg suggestions)
M._get_git_diffs = function()
	local hunks = gitsigns.get_hunks()
	local diffs = "\n"
	for _, hunk in ipairs(hunks) do
		diffs = diffs .. hunk.head .. "\n" .. table.concat(hunk.lines, "\n") .. "\n"
	end
	return diffs
end

-- prompt for git commit suggestions
M.git_commits_prompt = function()
	local buf = vim.fn.expand("%:p:h")
	local rel_path = vim.fn.fnamemodify(buf, ":~:.")
	local prm = [[Write a JSON file of top ]]
		.. options.git.count
		.. [[ suggestions of git commit messages following commitlint format for the following diffs.]]
		.. [[ Your output must be a parsable JSON with no code fences around it.```]]
		.. M._get_git_diffs()
		.. [[```. Your JSON output should follow the format: {{ "type": <type>, "scope": <scope>, "subject": <subject> }, ...}.
           Some context:
           file path: ]]
		.. rel_path
	return prm
end

M.chat_git_commitdiffs = function()
	local _get_user_input = function(callback)
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
					id = "git_form",
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
					border_label = "I want to know ...?",
					max_lines = 8,
					validate = n.validator.min_length(10),
					placeholder = [[when openfoam shifted from default MPI communicator to its own.]],
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
	local quick_parser = function(parsed_data)
        local input = parsed_data[1] -- TODO: handle multiple inputs, the AI engine returns 3 by default
        vim.schedule(function() diffs_search(input) end)
	end
	_get_user_input(function()
		local prm = [[What is the keyword to search Git diffs for if I want to know ]]
			.. M.input.ask
			.. [[Give a list of 3 code symbols as keywords. Your output must be parseable JSON]]
		core.chat_code_command("git", function()
			return prm
		end, quick_parser, function() end, function() end)
	end)
end

M.chat_git_commitmsg = function()
	local parser = function(parsed_data)
		if parsed_data ~= nil then
			for _, entry in ipairs(parsed_data) do
				local git = {
					source = options.source,
					severity = core.to_vim_severity("INFO"),
					message = entry.type .. "(" .. entry.scope .. "): " .. entry.subject,
				}
				vim.list_extend(M.commitmsgs, { git })
			end
		else
			vim.notify("Response from AI agent didn't adhere to expected structure.", vim.log.levels.WARN)
		end
	end
	core.chat_code_command(
		"git",
		M.git_commits_prompt,
		parser,
		function()
			return nil
		end, -- no diagnostics
		function() -- custom previewer with no text edits
			local original_buf = vim.api.nvim_win_get_buf(0)
			pickers
				.new({}, {
					prompt_title = "Select a Commit Message",
					finder = finders.new_table({
						results = M.commitmsgs,
						entry_maker = function(entry)
							return {
								display = entry.message,
								value = entry.message,
								ordinal = entry.message,
								bufnr = original_buf,
							}
						end,
					}),
					sorter = sorters.get_generic_fuzzy_sorter(),
					attach_mappings = function(prompt_bufnr)
						actions.select_default:replace(function()
							local selection = require("telescope.actions.state").get_selected_entry(prompt_bufnr)
							if selection then
								vim.fn.setreg("+", selection.value)
								vim.notify("Copied commit msg to +reg: " .. selection.value)
							end
							actions.close(prompt_bufnr)
						end)
						return true
					end,
				})
				:find()
		end
	)
end

return M
