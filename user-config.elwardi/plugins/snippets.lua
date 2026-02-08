-- User snippets extension for LuaSnip
-- This extends the base LuaSnip plugin with custom snippets
return {
    "L3MON4D3/LuaSnip",
    config = function()
        local ls = require 'luasnip'
        local s = ls.snippet
        local sn = ls.snippet_node
        local t = ls.text_node
        local d = ls.dynamic_node
        local i = ls.insert_node
        local c = ls.choice_node
        local f = ls.function_node

        local get_print_statement = function()
            local filetype = vim.bo.filetype
            local fileext = vim.fn.expand('%:e')
            if filetype == 'cpp' and (fileext == "C" or fileext == "H") then
                filetype = 'foam'
            end
            local print_statements = {
                lua = 'print',
                python = 'print',
                javascript = 'console.log',
                typescript = 'console.log',
                java = 'System.out.println',
                foam = "Info<<",
                cpp = 'std::cout <<',
                c = 'printf',
                ruby = 'puts',
                go = 'fmt.Println',
                rust = 'println!',
            }
            return print_statements[filetype] or 'print', filetype
        end

        local get_debug_info = function(args, parent)
            local filename = vim.fn.expand('%:t')
            local line = vim.fn.line('.')
            local next_line = vim.fn.getline(line + 1):gsub("^%s+", "")
            local print_statement, ft = get_print_statement()

            if print_statement == 'printf' then
                return sn(nil, {
                    t(print_statement .. '("=== DEBUG (' .. filename .. ':' .. line .. ') at `' .. next_line .. '` ===\\n");')
                })
            elseif ft == 'cpp' then
                return sn(nil, {
                    t(print_statement ..
                        '"=== DEBUG (' .. filename .. ':' .. line .. ') at `' .. next_line .. '` ===" << std::endl;')
                })
            elseif ft == 'foam' then
                return sn(nil, {
                    t(print_statement .. '"=== DEBUG (' .. filename .. ':' .. line .. ') at `' .. next_line .. '` ===" << endl;')
                })
            else
                return sn(nil, {
                    t(print_statement .. '("=== DEBUG (' .. filename .. ':' .. line .. ') at `' .. next_line .. '` ===");')
                })
            end
        end

        local snippets = {
            s('DEBUG', {
                d(1, get_debug_info, {}),
            }),
            s('TODO', {
                t('TODO: '),
            }),
        }

        local function get_python_version()
            local version = vim.fn.system("python3 --version 2>&1")
            version = version:match("Python%s+(%d+%.%d+)")
            return version or "3.x"
        end

        ls.add_snippets("all", snippets)

        ls.add_snippets("markdown", {
            s("adr", {
                t({ "---", "layout: adr", "title: " }), i(1, "ADR Title"),
                t({ "", "related:", "    - " }), i(2, "Related ADR Title"),
                t({ "", "status: " }),
                c(3, { t("enforced"), t("proposed"), t("rejected"), t("deprecated"), t("superseded"), t("under-review") }),
                t({ "", "date: " }), t(os.date("%Y-%m-%d")),
                t({ "", "decision_makers:", "    - " }), i(4, "elwardi"),
                t({ "", "adr_tags:", "  - " }), i(5, "backend"),
                t({ "", "---", "" }),
                t({ "", "## Context and Problem Statement", "", "" }),
                i(6, "Describe the context and problem statement in two-three sentences, ending with a question."),
                t({ "", "",  "## Decision Drivers", "", "" }), i(7, "- Decision driver 1 (concern, force)"),
                t({ "", "", "## Considered Options", "", "" }), i(8, "- Option 1"),
                t({ "", "", "## Decision Outcome", "", "Chosen option: "}), i(9, "option"),
                t({ " because " }), i(10, "reasons wrt. decision drivers"),
                t({ "", "", "### Consequences", "", ""}),
                i(11, "- Positive, improves this and that"), t({"",""}),
                i(12, "- Neutral, changes this and that but has no significant effects"), t({"",""}),
                i(13, "- Negative, affects this and that"), t({"",""}),
                t({"", "", "### Confirmation", "", ""}), i(14, "How to confirm compliance with decision."),
                t({"", "", "## More information", "", ""}), i(15, "Any more information clarifying components of the decision."),
            }),
        })

        -- CSF document templates (from jira-interface config)
        do
            ---@param trigger string
            ---@param title_default string
            ---@param tmpl { description_sections?: table[], acceptance_criteria?: string[] }
            local function csf_template(trigger, title_default, tmpl)
                local nodes = {}
                local idx = 0

                table.insert(nodes, t({ "<h1>" }))
                idx = idx + 1
                table.insert(nodes, i(idx, title_default))
                table.insert(nodes, t({ "</h1>" }))

                table.insert(nodes, t({ "", "<h2>Summary</h2>", "<p>" }))
                idx = idx + 1
                table.insert(nodes, i(idx, "Summary"))
                table.insert(nodes, t({ "</p>" }))

                table.insert(nodes, t({ "", "<h2>Description</h2>" }))
                if tmpl.description_sections and #tmpl.description_sections > 0 then
                    for _, section in ipairs(tmpl.description_sections) do
                        table.insert(nodes, t({ "", "<h3>" .. section.heading .. "</h3>", "<p>" }))
                        idx = idx + 1
                        table.insert(nodes, i(idx, section.placeholder))
                        table.insert(nodes, t({ "</p>" }))
                    end
                else
                    table.insert(nodes, t({ "", "<p>" }))
                    idx = idx + 1
                    table.insert(nodes, i(idx, "Description"))
                    table.insert(nodes, t({ "</p>" }))
                end

                if tmpl.acceptance_criteria and #tmpl.acceptance_criteria > 0 then
                    table.insert(nodes, t({ "", "<h2>Acceptance Criteria</h2>", "<ac:task-list>" }))
                    for _, criteria in ipairs(tmpl.acceptance_criteria) do
                        table.insert(nodes, t({ "", "<ac:task><ac:task-status>incomplete</ac:task-status><ac:task-body>" }))
                        idx = idx + 1
                        table.insert(nodes, i(idx, criteria))
                        table.insert(nodes, t({ "</ac:task-body></ac:task>" }))
                    end
                    table.insert(nodes, t({ "", "</ac:task-list>" }))
                end

                table.insert(nodes, t({ "", "" }))
                table.insert(nodes, i(0))
                return s(trigger, nodes)
            end

            local templates = {}
            local jok, jira_config = pcall(require, "jira-interface.config")
            if jok then
                templates = (jira_config.options and next(jira_config.options) and jira_config.options.templates)
                    or jira_config.defaults.templates or {}
            end

            local csf_snippets = {}
            for _, def in ipairs({
                { trigger = "bug",     title = "Bug Report", key = "bug" },
                { trigger = "feature", title = "Feature",    key = "feature" },
                { trigger = "epic",    title = "Epic",       key = "epic" },
                { trigger = "task",    title = "Task",       key = "task" },
                { trigger = "issue",   title = "Issue",      key = "default" },
            }) do
                local tmpl = templates[def.key] or { description_sections = {}, acceptance_criteria = {} }
                table.insert(csf_snippets, csf_template(def.trigger, def.title, tmpl))
            end

            ls.add_snippets("csf", csf_snippets)
        end

        ls.add_snippets("python", {
            s("uv_script", {
                t({"# /// script"}),
                t({"", "# requires-python = \">=", }),
                f(get_python_version, {}),
                t({"\"" }),
                t({"", "# dependencies = [", "# "}),
                i(1, "\"numpy\","),
                t({"", "# ]"}),
                t({"", "# ///"}),
            }),
        })
    end,
}
