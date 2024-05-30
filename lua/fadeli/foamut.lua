local M              = {}

local icons          = require("user.lspicons")
M.notif_opts = {
    timeout = 20000,
    title = "FoamUT tests",
}

-- function to check foamUT env. vars.
M._check_env         = function()
    local foamut = vim.loop.os_getenv("FOAM_FOAMUT")
    local foam = vim.loop.os_getenv("WM_PROJECT")
    if foam == nil or foam == "" then
        vim.print("OpenFOAM not sourced.")
        return nil
    end
    if foamut == nil or foamut == "" then
        vim.print("FOAM_FOAMUT env. var. not set.")
        return nil
    end
    return foamut
end

-- function to run Alltest with custom args
M._run_async_alltest = function(args, callback)
    local foamut_path = M._check_env()
    if foamut_path == nil then
        return
    end
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)
    local output_buffer = {}
    local error_buffer = {}
    local handle, pid
    handle, pid = vim.loop.spawn("./Alltest", {
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
        vim.print("Failed to spawn Alltest process, OpenFOAM not sourced?")
    end
end

M._select_unit_tests = function(tests, callback)
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
                        { width = 15, },
                        { width = 10, },
                        { width = 30, },
                        { remaining = true, },
                    },
                }
                return {
                    display = function(e)
                        return display {
                            { entry.lib,                       "LspInfoFiletype" },
                            { entry.mode,                      "TelescopePreviewExecute" },
                            { table.concat(entry.tags, " | "), "TelescopeResultsOperator" },
                            { entry.name,                      "TelescopeResultsNumber" },
                        }
                    end,
                    value = entry.name,
                    properties = entry,
                    ordinal = entry.lib .. "/" .. entry["source-location"].filename .. " - " .. entry.name .. table.concat(entry.tags, ' | '),
                }
            end,
        },
        sorter = sorters.get_generic_fuzzy_sorter(),
        attach_mappings = function(_, map)
            map('i', '<CR>', function(prompt_bufnr, mode, target)
                local picker = action_state.get_current_picker(prompt_bufnr)
                local prompt = picker:_get_prompt()
                local entries = picker:get_multi_selection()
                actions.close(prompt_bufnr)
                if entries then
                    for _, entry in ipairs(entries) do
                        callback(entry)
                    end
                end
            end)
            return true
        end,
    }):find()
end


-- function to add assertions to table
M._add_assertions = function(paths, assertions, section_stack, metadata)
    for _, path in ipairs(paths) do
        if path.kind == "section" then
            table.insert(section_stack, path.name)
        end
        local assertion = {}
        if path.kind == "assertion" then
            local status = icons.diagnostics.BoldError
            local type = "E"
            if path.status then
                status = icons.diagnostics.BoldHint
                type = "I"
            end
            local scope = table.concat(section_stack, " > ")
            scope = string.gsub(scope, "%s+", " ")
            assertion.filename = metadata.root_dir ..
                "/tests/" .. metadata.lib .. "/" .. path["source-location"].filename
            assertion.module = metadata.lib
            assertion.lnum = path["source-location"].line
            assertion.col = 1
            assertion.text = status .. " " .. metadata.tags .. " " .. scope
            assertion.type = type
            table.insert(assertions, assertion)
        end
        if path.path ~= nil then
            M._add_assertions(path.path, assertions, section_stack, metadata)
        end
        if path.kind == "section" then
            table.remove(section_stack)
        end
    end
end

M._send_tests_to_qfl = function(test_info, tests)
    local assertions = {}
    if tests == nil then
        return
    end
    local foamut = M._check_env()
    for _, lib in ipairs(tests) do
        if vim.tbl_isempty(lib["test-run"]["test-cases"]) then
            goto continue
        end
        local catch2 = lib.metadata["catch2-version"]
        local libname = lib.metadata.name
        local metadata = {
            catch2 = catch2,
            lib = libname,
            root_dir = foamut,
            filters = lib.metadata.filters,
            tags = table.concat(test_info.properties.tags, " | "),
        }
        for _, testcase in ipairs(lib["test-run"]["test-cases"]) do
            for _, run in ipairs(testcase.runs) do
                M._add_assertions(run.path, assertions, {}, metadata)
            end
        end
        ::continue::
    end
    vim.fn.setqflist(assertions, 'a')
    vim.cmd("copen")
end

-- function to list available tests
M.FoamUtListTests = function()
    vim.fn.setqflist({}, 'r')
    local tests = {}
    local args = {
        "--no-parallel",
        "-r", "json",
        "--filenames-as-tags",
        "--list-tests",
        "--list-tags",
    }
    if vim.g.loaded_categories.ux then
        require("noice").notify("Comiling test binaries to list FoamUT tests", "info", M.notif_opts)
    else
        vim.notify("Comiling test binaries to list FoamUT tests")
    end
    M._run_async_alltest(args, function(code, signal, stdout_buffer, stderr_buffer)
        vim.schedule(function()
            local output = "[ " .. stdout_buffer .. "]"
            output = string.gsub(output, ",,", ",")
            output = string.gsub(output, ",]", "]")
            local success, libs = pcall(vim.json.decode, output)
            if not success then
                vim.print("Failed to parse json output")
                return
            end
            tests = {}
            for _, lib in ipairs(libs) do
                local libname = lib.metadata.name
                local filters = lib.metadata.filters
                local comps = {}
                for comp in string.gmatch(filters, "%[[^%]]+%]") do
                    if comp ~= "[serial]" or comp ~= "[parallel]" then
                        table.insert(comps, comp)
                    end
                end
                for _, test in ipairs(lib.listings.tests) do
                    -- filter only serial tests
                    local is_serial = false
                    for _, tag in ipairs(test.tags) do
                        if tag == "serial" then
                            is_serial = true
                        end
                    end
                    if is_serial then
                        local new_entry = vim.deepcopy(test)
                        new_entry.mode = "serial"
                        new_entry.lib = libname
                        new_entry.tags = comps
                        table.insert(tests, new_entry)
                    end
                end
            end
            if vim.tbl_isempty(tests) then
                vim.print("No tests found")
                return
            end
            M._select_unit_tests(tests, function(selection)
                M.FoamUtRunTest(selection)
            end)
        end)
    end)
end

-- function to run a specific test
M.FoamUtRunTest = function(test)
    local args = {
        "-r", "json",
    }
    if test.properties.mode == "serial" then
        table.insert(args, 1, "--no-parallel")
    end
    if test.properties.mode == "parallel" then
        table.insert(args, 1, "--no-serial")
    end
    table.insert(args, test.value)
    if vim.g.loaded_categories.ux then
        require("noice").notify("Running Alltest with selected tests", "info", M.notif_opts)
    else
        vim.notify("Running Alltest with selected tests")
    end
    M._run_async_alltest(args, function(code, signal, stdout_buffer, stderr_buffer)
        vim.schedule(function()
            stdout_buffer = "[ " .. stdout_buffer .. "]"
            stdout_buffer = string.gsub(stdout_buffer, ",,", ",")
            stdout_buffer = string.gsub(stdout_buffer, ",]", "]")
            local success, parsed_data = pcall(vim.json.decode, stdout_buffer)
            if not success then
                vim.print("Failed to parse json output")
                return
            end
            M._send_tests_to_qfl(test, parsed_data)
        end)
    end)
end

return M
