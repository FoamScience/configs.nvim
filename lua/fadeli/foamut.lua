local M        = {
    ft = { "cpp" },
}
local lspicons = require('user.lspicons')

local notifier = vim.notify
if vim.g.loaded_categories.ux then
    notifier = require("noice").notify
end

M.notify_opts                 = {
    timeout = 20000,
    title = "foamUT",
}

M.ns_id                       = vim.api.nvim_create_namespace("foamut_test_status")
M.virt_ns_id                  = vim.api.nvim_create_namespace("foamut_virt_text")
M._cached_tests               = {}

-- Helper to parse and clean foamut JSON output
M._parse_json_output          = function(buffer)
    local output = "[" .. buffer .. "]"
    output = string.gsub(output, ",,", ",")
    output = string.gsub(output, ",]", "]")
    return pcall(vim.json.decode, output)
end

-- Helper to extract library name from file path
M._get_library_name_from_path = function(filepath)
    -- Match pattern: */tests/{libname}/*.C
    local libname = filepath:match("tests/([^/]+)/[^/]+%.C$")
    return libname
end

-- Helper to find test by name in cached tests
M._find_test_by_name          = function(test_name)
    for _, test in ipairs(M._cached_tests) do
        if test.name == test_name then
            return test
        end
    end
    return nil
end

-- Helper to get test name at cursor using tree-sitter
M._get_test_name_at_cursor    = function(bufnr, line, col)
    -- Try to get tree-sitter parser for cpp
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "cpp")
    if not ok or not parser then
        return nil, "cpp tree-sitter parser not available"
    end

    -- Parse the buffer
    local tree = parser:parse()[1]
    if not tree then
        return nil, "Failed to parse buffer"
    end

    local root = tree:root()

    -- Get node at cursor (convert to 0-indexed)
    local node = root:named_descendant_for_range(line - 1, col, line - 1, col)
    if not node then
        return nil, "No node at cursor"
    end

    -- Strategy: Walk up the tree to find either:
    -- 1. An expression_statement (cursor on test declaration)
    -- 2. A compound_statement that is preceded by an expression_statement (cursor inside test body)
    local current = node
    local expr_stmt = nil
    local compound_stmt = nil

    while current do
        if current:type() == "expression_statement" then
            expr_stmt = current
            break
        elseif current:type() == "compound_statement" then
            -- Found compound statement, check if previous sibling is expression_statement
            compound_stmt = current
            local prev_sibling = current:prev_named_sibling()
            if prev_sibling and prev_sibling:type() == "expression_statement" then
                expr_stmt = prev_sibling
                break
            end
        end
        current = current:parent()
    end

    if not expr_stmt then
        return nil, "Not in a test case"
    end

    -- If we found via compound_statement, verify it's the right one
    if compound_stmt then
        local next_sibling = expr_stmt:next_named_sibling()
        if not next_sibling or next_sibling ~= compound_stmt then
            return nil, "Not a test case declaration"
        end
    else
        -- Check if this expression_statement is followed by a compound_statement (test body)
        local next_sibling = expr_stmt:next_named_sibling()
        if not next_sibling or next_sibling:type() ~= "compound_statement" then
            return nil, "Not a test case declaration"
        end
    end

    -- Find call_expression in the expression_statement
    local call_expr = nil
    for child in expr_stmt:iter_children() do
        if child:type() == "call_expression" then
            call_expr = child
            break
        end
    end

    if not call_expr then
        return nil, "No call expression found"
    end

    -- Check if function name is TEST_CASE or SCENARIO
    local func_node = call_expr:field("function")[1]
    if not func_node then
        return nil, "No function in call expression"
    end

    local func_text = vim.treesitter.get_node_text(func_node, bufnr)
    if func_text ~= "TEST_CASE" and func_text ~= "SCENARIO" then
        return nil, "Not a TEST_CASE or SCENARIO"
    end

    -- Get arguments
    local args_node = call_expr:field("arguments")[1]
    if not args_node or args_node:type() ~= "argument_list" then
        return nil, "No arguments in test case"
    end

    -- Find first string_literal (the test name)
    local test_name_node = nil
    for child in args_node:iter_children() do
        if child:type() == "string_literal" then
            test_name_node = child
            break
        end
    end

    if not test_name_node then
        return nil, "No test name found"
    end

    -- Extract string_content from string_literal
    local string_content = nil
    for child in test_name_node:iter_children() do
        if child:type() == "string_content" then
            string_content = child
            break
        end
    end

    if not string_content then
        -- Empty string or no content
        return "", nil
    end

    local test_name = vim.treesitter.get_node_text(string_content, bufnr)
    return test_name, nil
end

-- Helper to recursively extract assertions from test path
M._extract_assertions         = function(path, assertions, foamut_path, libname)
    for _, item in ipairs(path) do
        if item.kind == "assertion" and item["source-location"] then
            local test_file = foamut_path .. "/tests/" .. libname .. "/" .. item["source-location"].filename
            table.insert(assertions, {
                file = test_file,
                line = item["source-location"].line - 1, -- 0-indexed
                status = item.status,
            })
        end
        -- Recursively process nested paths
        if item.path then
            M._extract_assertions(item.path, assertions, foamut_path, libname)
        end
    end
end

-- Helper to set diagnostics for test results
M._set_test_diagnostics       = function(parsed_data, foamut_path)
    -- Collect all assertions by file
    local diagnostics_by_file = {}
    local virt_text_by_file = {}

    for _, lib in ipairs(parsed_data) do
        local libname = lib.metadata.name
        if lib["test-run"] and lib["test-run"]["test-cases"] then
            for _, testcase in ipairs(lib["test-run"]["test-cases"]) do
                for _, run in ipairs(testcase.runs) do
                    if run.path then
                        local assertions = {}
                        M._extract_assertions(run.path, assertions, foamut_path, libname)
                        -- Group assertions by file
                        for _, assertion in ipairs(assertions) do
                            if not diagnostics_by_file[assertion.file] then
                                diagnostics_by_file[assertion.file] = {}
                            end
                            if not virt_text_by_file[assertion.file] then
                                virt_text_by_file[assertion.file] = {}
                            end

                            local severity = assertion.status
                                and vim.diagnostic.severity.HINT
                                or vim.diagnostic.severity.ERROR
                            local message = assertion.status and "assertion passed" or "assertion failed"
                            local icon = assertion.status and lspicons.ui.BoxChecked or lspicons.ui.Circle
                            local virt_text = assertion.status
                                and string.format(" %s ", icon)
                                or string.format(" %s  ", icon)
                            local hl_group = assertion.status and "DiagnosticVirtualTextHint" or
                                "DiagnosticVirtualTextError"

                            table.insert(diagnostics_by_file[assertion.file], {
                                lnum = assertion.line,
                                col = 0,
                                severity = severity,
                                source = M.notify_opts.title,
                                message = message,
                            })

                            table.insert(virt_text_by_file[assertion.file], {
                                line = assertion.line,
                                text = virt_text,
                                hl = hl_group,
                            })
                        end
                    end
                end
            end
        end
    end

    -- Set diagnostics for each file
    for file, diagnostics in pairs(diagnostics_by_file) do
        local bufnr = vim.fn.bufnr(file)

        -- If buffer not loaded, create an unlisted buffer for diagnostics
        if bufnr == -1 then
            bufnr = vim.fn.bufadd(file)
        end

        -- Get existing diagnostics for deduplication
        local existing = vim.diagnostic.get(bufnr, { namespace = M.ns_id })

        -- Create a map of existing diagnostics by line number for deduplication
        local existing_by_line = {}
        for _, diag in ipairs(existing) do
            existing_by_line[diag.lnum] = diag
        end

        -- Add new diagnostics, replacing any on the same line
        for _, diag in ipairs(diagnostics) do
            existing_by_line[diag.lnum] = diag
        end

        -- Convert back to array
        local all_diagnostics = {}
        for _, diag in pairs(existing_by_line) do
            table.insert(all_diagnostics, diag)
        end

        -- Set diagnostics for the buffer
        vim.diagnostic.set(M.ns_id, bufnr, all_diagnostics, {})

        -- Only set virtual text if buffer is actually loaded in a window
        if vim.fn.bufloaded(bufnr) == 1 then
            -- Clear and rebuild ALL virtual text from ALL diagnostics
            vim.api.nvim_buf_clear_namespace(bufnr, M.virt_ns_id, 0, -1)

            -- Build virtual text from all diagnostics in the buffer
            for _, diag in ipairs(all_diagnostics) do
                local icon = (diag.severity == vim.diagnostic.severity.HINT)
                    and lspicons.ui.BoxChecked
                    or lspicons.ui.Circle
                local virt_text = (diag.severity == vim.diagnostic.severity.HINT)
                    and string.format(" %s ", icon)
                    or string.format(" %s  ", icon)
                local hl_group = (diag.severity == vim.diagnostic.severity.HINT)
                    and "DiagnosticVirtualTextHint"
                    or "DiagnosticVirtualTextError"

                vim.api.nvim_buf_set_extmark(bufnr, M.virt_ns_id, diag.lnum, 0, {
                    virt_text = { { virt_text, hl_group } },
                    virt_text_pos = "eol",
                    hl_mode = "combine",
                })
            end
        end

        -- Add diagnostics to quickfix list (regardless of buffer state)
        local qf_items = {}
        for _, diag in ipairs(all_diagnostics) do
            table.insert(qf_items, {
                filename = file,
                lnum = diag.lnum + 1, -- quickfix uses 1-indexed
                col = diag.col + 1,
                text = string.format("[%s] %s", diag.source, diag.message),
                type = (diag.severity == vim.diagnostic.severity.ERROR) and "E" or "I",
            })
        end

        -- Append to existing quickfix list
        vim.fn.setqflist(qf_items, 'a')
    end
end

-- function to check foamUT env. vars.
M._check_env                  = function()
    local foamut = vim.loop.os_getenv("FOAM_FOAMUT")
    local foam = vim.loop.os_getenv("WM_PROJECT")
    if foam == nil or foam == "" then
        notifier("OpenFOAM not sourced.", "error", M.notify_opts)
        return nil
    end
    if foamut == nil or foamut == "" then
        notifier("FOAM_FOAMUT env. var. not set.", "error", M.notify_opts)
        return nil
    end
    return foamut
end

-- function to run foamut with custom args
M._run_async_alltest          = function(args, callback)
    local foamut_path = M._check_env()
    if foamut_path == nil then
        return
    end
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)
    local output_buffer = {}
    local error_buffer = {}
    local handle, pid
    handle, pid = vim.loop.spawn("./foamut", {
        args = args,
        cwd = foamut_path,
        stdio = { nil, stdout, stderr },
    }, function(code, signal)
        stdout:read_stop()
        stderr:read_stop()
        stdout:close()
        stderr:close()
        handle:close()
        callback(code, signal, table.concat(output_buffer), table.concat(error_buffer))
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
                table.insert(error_buffer, data)
            end
        end)
    else
        notifier("Failed to spawn foamut process, OpenFOAM not sourced?", "error", M.notify_opts)
    end
end

M._select_unit_tests          = function(tests, callback)
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local sorters = require('telescope.sorters')
    local actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')

    -- Use Telescope to display and select the names
    pickers.new({}, {
        prompt_title = "Select a Unit Test",
        results_title = "Unit Tests",
        finder = finders.new_table {
            results = tests,
            entry_maker = function(entry)
                local result_width = vim.api.nvim_win_get_width(0)
                local display = require('telescope.pickers.entry_display').create {
                    separator = " | ",
                    items = {
                        { width = 25, },
                        { width = 12, },
                        { width = 20, },
                        { remaining = true, },
                    },
                }
                local filename = entry["source-location"].filename
                local libfile = entry.lib .. ":" .. filename
                local tags_str = table.concat(entry.tags, " | ")
                return {
                    display = function(e)
                        return display {
                            { libfile,    "LspInfoFiletype" },
                            { entry.mode, "TelescopePreviewExecute" },
                            { tags_str,   "TelescopeResultsOperator" },
                            { entry.name, "TelescopeResultsNumber" },
                        }
                    end,
                    value = entry.name,
                    properties = entry,
                    ordinal = libfile .. " " .. entry.mode .. " " .. tags_str .. " " .. entry.name,
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        attach_mappings = function(_, map)
            local run_selected_tests = function(prompt_bufnr)
                local picker = action_state.get_current_picker(prompt_bufnr)
                local multi = picker:get_multi_selection()
                actions.close(prompt_bufnr)

                local selected_tests = {}

                -- If no multi-selection, get the current selection
                if vim.tbl_isempty(multi) then
                    local selection = action_state.get_selected_entry()
                    if selection then
                        table.insert(selected_tests, selection)
                    end
                else
                    -- Collect all multi-selected tests
                    selected_tests = multi
                end

                if #selected_tests > 0 then
                    callback(selected_tests)
                end
            end

            map('i', '<CR>', run_selected_tests)
            map('n', '<CR>', run_selected_tests)
            return true
        end,
    }):find()
end

-- Internal function to discover tests (serial + standalone)
-- Calls callback with (tests_array) on success, or (nil, error_msg) on failure
M._discover_tests             = function(callback, show_notification)
    show_notification = show_notification == nil and true or show_notification

    local tests = {}
    local serial_tests = {}
    local standalone_tests = {}
    local retried = false

    local function get_serial_tests()
        -- First, get serial tests
        local serial_args = {
            "-r", "json",
            "-#",
            "--list-tests",
            "--list-tags",
        }

        if show_notification then
            notifier("Discovering foamUT tests...", "info", M.notify_opts)
        end

        M._run_async_alltest(serial_args, function(code, signal, stdout_buffer, stderr_buffer)
            -- Parse and process serial tests outside vim.schedule
            local success, libs = M._parse_json_output(stdout_buffer)

            if not success then
                if not retried then
                    -- First compilation might have mixed output, retry once
                    retried = true
                    vim.schedule(function()
                        if show_notification then
                            notifier("Failed to parse json output (likely compilation), retrying...", "warn",
                                M.notify_opts)
                        end
                        get_serial_tests()
                    end)
                else
                    vim.schedule(function()
                        callback(nil, "Failed to parse json output for serial tests after retry")
                    end)
                end
                return
            end

            -- Reset retry flag on success
            retried = false

            -- Process serial tests
            for _, lib in ipairs(libs) do
                local libname = lib.metadata.name
                local filters = lib.metadata.filters
                local comps = {}
                for comp in string.gmatch(filters, "%[[^%]]+%]") do
                    local tag_content = comp:match("%[(.+)%]")
                    if comp ~= "[serial]" and comp ~= "[parallel]" and comp ~= "[standalone]"
                        and not (tag_content and tag_content:match("^#")) then
                        table.insert(comps, comp)
                    end
                end
                for _, test in ipairs(lib.listings.tests) do
                    -- filter only serial tests
                    local is_serial = false
                    for _, tag in ipairs(test.tags) do
                        if tag == "serial" then
                            is_serial = true
                            break
                        end
                    end
                    if is_serial then
                        local new_entry = vim.deepcopy(test)
                        new_entry.mode = "serial"
                        new_entry.lib = libname
                        new_entry.tags = comps
                        table.insert(serial_tests, new_entry)
                    end
                end
            end

            -- Now get standalone tests
            local standalone_args = {
                "--standalone",
                "-r", "json",
                "-#",
                "--list-tests",
                "--list-tags",
            }

            M._run_async_alltest(standalone_args, function(code2, signal2, stdout_buffer2, stderr_buffer2)
                -- Parse and process standalone tests outside vim.schedule
                local success2, libs2 = M._parse_json_output(stdout_buffer2)

                if success2 then
                    -- Process standalone tests
                    for _, lib in ipairs(libs2) do
                        local libname = lib.metadata.name
                        for _, test in ipairs(lib.listings.tests) do
                            local new_entry = vim.deepcopy(test)
                            new_entry.mode = "standalone"
                            new_entry.lib = libname
                            -- Standalone tests don't get case tags, only their own test tags
                            local test_tags = {}
                            for _, tag in ipairs(test.tags) do
                                if tag ~= "serial" and tag ~= "parallel" and tag ~= "standalone" and not tag:match("^#") then
                                    table.insert(test_tags, tag)
                                end
                            end
                            new_entry.tags = test_tags
                            table.insert(standalone_tests, new_entry)
                        end
                    end
                    -- Merge serial and standalone tests
                    tests = vim.list_extend(serial_tests, standalone_tests)
                else
                    -- Continue with only serial tests
                    tests = serial_tests
                end

                -- Cache the discovered tests for cursor-based execution
                M._cached_tests = tests

                -- Call the callback with the tests
                vim.schedule(function()
                    if not success2 and show_notification then
                        notifier("Failed to parse json output for standalone tests, showing only serial tests", "warn",
                            M.notify_opts)
                    end

                    if vim.tbl_isempty(tests) then
                        callback(nil, "No tests found")
                        return
                    end

                    callback(tests)
                end)
            end)
        end)
    end

    -- Start the process
    get_serial_tests()
end

-- function to list available tests
M.FoamUtListTests             = function()
    M._discover_tests(function(tests, err)
        if not tests then
            notify(err or "Failed to discover tests", "error", M.notify_opts)
            return
        end
        M._select_unit_tests(tests, function(selected_tests)
            M.FoamUtRunTests(selected_tests)
        end)
    end, true)
end

-- Helper to run a single test
M._run_single_test            = function(test, foamut_path)
    local args = {}

    -- Add mode-specific flags
    if test.properties.mode == "parallel" then
        table.insert(args, "--parallel")
    elseif test.properties.mode == "standalone" then
        table.insert(args, "--standalone")
    end

    -- Add common args
    table.insert(args, "-r")
    table.insert(args, "json")
    -- Pass test name directly - Catch2 will do exact match by default
    table.insert(args, test.value)

    M._run_async_alltest(args, function(code, signal, stdout_buffer, stderr_buffer)
        -- Parse JSON outside vim.schedule for better performance
        local success, parsed_data = M._parse_json_output(stdout_buffer)

        -- Determine overall test result by checking totals
        local test_passed = false
        local total_failed = 0
        local total_passed = 0

        if success and parsed_data and #parsed_data > 0 then
            for _, lib in ipairs(parsed_data) do
                if lib["test-run"] and lib["test-run"].totals then
                    local assertions = lib["test-run"].totals.assertions
                    if assertions then
                        total_failed = total_failed + (assertions.failed or 0)
                        total_passed = total_passed + (assertions.passed or 0)
                    end
                end
            end
            test_passed = (total_failed == 0 and total_passed > 0)
        end

        -- Only schedule UI updates
        vim.schedule(function()
            if not success then
                notifier("Failed to parse json output for: " .. test.value, "error", M.notify_opts)
                return
            end
            if total_passed == 0 and total_failed == 0 then
                notifier("No test assertions found in output for: " .. test.value, "warn", M.notify_opts)
                return
            end
            M._set_test_diagnostics(parsed_data, foamut_path)
        end)
    end)
end

-- function to run tests (single or multiple)
M.FoamUtRunTests              = function(tests)
    -- Normalize input to array
    if not vim.islist(tests) then
        tests = { tests }
    end

    if #tests == 0 then
        return
    end

    -- Check env once at the start
    local foamut_path = M._check_env()
    if not foamut_path then
        return
    end

    -- Deduplicate tests
    local seen = {}
    local unique_tests = {}
    for _, test in ipairs(tests) do
        if not seen[test.value] then
            table.insert(unique_tests, test)
            seen[test.value] = true
        end
    end

    local msg = string.format("Running %d test%s", #unique_tests, #unique_tests > 1 and "s" or "")
    notifier(msg, "info", M.notify_opts)
    -- Run each test individually
    for _, test in ipairs(unique_tests) do
        M._run_single_test(test, foamut_path)
    end
end

-- Backward compatibility alias
M.FoamUtRunTest               = function(test)
    M.FoamUtRunTests(test)
end

-- Function to run test at cursor position
M.FoamUtRunTestAtCursor       = function()
    -- Check environment
    local foamut_path = M._check_env()
    if not foamut_path then
        return
    end

    -- Get current buffer and verify it's a C++ file
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.bo[bufnr].filetype
    if filetype ~= "cpp" then
        notifier("Not in a C++ file!", "error", M.notify_opts)
        return
    end

    -- Get buffer path and extract library name
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    local libname = M._get_library_name_from_path(filepath)
    if not libname then
        notifier("File is not in tests directory", "error", M.notify_opts)
        return
    end

    -- Get cursor position
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1]
    local col = cursor[2]

    -- Extract test name at cursor
    local test_name, err = M._get_test_name_at_cursor(bufnr, line, col)
    if not test_name then
        notifier(err or "No test case found at cursor", "warn", M.notify_opts)
        return
    end

    -- Helper function to run the test once we have it
    local function run_test_by_name(test_name_to_run)
        -- Find test in cached tests
        local cached_test = M._find_test_by_name(test_name_to_run)
        if not cached_test then
            notify(string.format("Test '%s' not found after discovery", test_name_to_run), "warn", M.notify_opts)
            return
        end

        -- Verify library matches (optional - could be symlinked)
        if cached_test.lib ~= libname then
            notifier(
                string.format("Library mismatch (file: %s, cached: %s)", libname, cached_test.lib),
                "warn", M.notify_opts
            )
        end

        -- Build test object in the format expected by _run_single_test
        local test = {
            value = cached_test.name,
            properties = cached_test
        }

        -- Notify user
        local mode_str = cached_test.mode == "standalone" and " (standalone)" or ""
        notifier(string.format("Running test: %s%s", cached_test.name, mode_str), "info", M.notify_opts)

        -- Run the test
        M._run_single_test(test, foamut_path)
    end

    -- Check if tests are cached, if not discover them first
    if vim.tbl_isempty(M._cached_tests) then
        M._discover_tests(function(tests, err)
            if not tests then
                notifier(err or "Failed to discover tests", "error", M.notify_opts)
                return
            end
            -- Now run the test
            run_test_by_name(test_name)
        end, false) -- show_notification = false (silent discovery)
    else
        -- Tests already cached, run immediately
        run_test_by_name(test_name)
    end
end

return M
