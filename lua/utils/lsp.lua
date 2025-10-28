local M = {}

-- Experimental support for UV path detection
-- supporting:
-- - UV Projects
-- - UV standalone scripts
M.find_uv_python_path = function(bufnr, client, callback)
    local uv_path = vim.fn.exepath("uv")
    if uv_path == "" then
        callback(false, nil)
        return
    end

    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then
        callback(false, nil)
        return
    end

    -- read first 10 lines, looking for: /// script
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 10, false)
    local is_uv_script = false
    for _, line in ipairs(lines) do
        if line:match("^#[%s]*///[%s]*script") then
            is_uv_script = true
            break
        end
    end

    local dir = vim.fn.fnamemodify(filepath, ":h")
    local has_fidget, progress = pcall(require, "fidget.progress")
    local handle
    if has_fidget then
        handle = progress.handle.create({
            title = "UV Python",
            message = "Checking configuration...",
            lsp_client = client and { name = client.name } or nil,
        })
    end

    local function report_progress(message, percentage)
        if handle then
            handle:report({
                message = message,
                percentage = percentage,
            })
        end
    end
    local function end_progress(message)
        if handle then
            handle:finish(message)
        end
    end
    report_progress("Checking UV configuration...", 0)

    local function check_script_python()
        if not is_uv_script then
            Find_project_python()
            return
        end
        report_progress("Detecting UV script environment...", 20)
        vim.system(
            { "uv", "python", "find", "--script", filepath },
            { text = true, timeout = 1000 },
            vim.schedule_wrap(function(script_result)
                Find_project_python(script_result)
            end)
        )
    end

    function Find_project_python(script_result)
        report_progress("Finding Python interpreter...", 40)
        vim.system(
            { "uv", "python", "find" },
            { text = true, timeout = 1000, cwd = dir },
            vim.schedule_wrap(function(project_result)
                if is_uv_script then
                    if script_result and script_result.stdout == project_result.stdout then
                        Create_script_env()
                    else
                        Finalize_result(script_result)
                    end
                else
                    Finalize_result(project_result)
                end
            end)
        )
    end

    function Create_script_env()
        report_progress("Creating UV script environment...", 60)
        vim.system(
            { "uv", "run", "--script", filepath, "--", "--version" },
            { text = true, timeout = 5000 },
            vim.schedule_wrap(function(_)
                report_progress("Finalizing script environment...", 80)
                vim.system(
                    { "uv", "python", "find", "--script", filepath },
                    { text = true, timeout = 1000 },
                    vim.schedule_wrap(function(final_result)
                        Finalize_result(final_result)
                    end)
                )
            end)
        )
    end

    function Finalize_result(result)
        if not result or not result.stdout then
            end_progress("UV detection failed")
            callback(is_uv_script, nil)
            return
        end

        local python_path = result.stdout:match("^%s*(.-)%s*$")
        if python_path ~= "" and vim.fn.executable(python_path) == 1 then
            if is_uv_script and python_path:match(vim.fn.fnamemodify(filepath, ":t:r")) == nil then
                end_progress("Using global Python paths")
            elseif is_uv_script then
                end_progress("UV script environment configured")
            else
                end_progress("UV project environment configured")
            end
            callback(is_uv_script, python_path)
        else
            end_progress("No valid Python interpreter found")
            callback(is_uv_script, nil)
        end
    end

    check_script_python()
end

-- Enables workspace-wide diagnostics; enabled only for select
-- filetypes+LSP combinations (eg. clangd)
M.workspace_diagnostics = function(client, bufnr, workspace_files)
    if not vim.tbl_get(client.server_capabilities, 'textDocumentSync', 'openClose') then
        return
    end
    for _, path in ipairs(workspace_files) do
        if path == vim.api.nvim_buf_get_name(bufnr) then
            goto continue
        end
        local filetype = vim.filetype.match({ filename = path })
        if not vim.tbl_contains(client.config.filetypes, filetype) then
            goto continue
        end
        local params = {
            textDocument = {
                uri = vim.uri_from_fname(path),
                version = 0,
                text = vim.fn.join(vim.fn.readfile(path), "\n"),
                languageId = filetype
            }
        }
        client.notify('textDocument/didOpen', params)
        ::continue::
    end
end


return M
