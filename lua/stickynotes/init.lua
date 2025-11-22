local M = {}

M.config = {
    width = 80,
    height = 0.8,
    border = "single", -- see help for winborder
    debug = false,
}

M.state = {
    win_id = nil,
    buf_id = nil,
    current_note = nil,
    project_root = nil,
}

local function hash_path(path)
    local hash = vim.fn.sha256(path)
    return hash:sub(1, 16)
end

function M.get_project_root()
    local saved_cwd = vim.fn.getcwd()
    local root = nil

    local ok, project = pcall(require, "project_nvim.project")
    if ok and project then
        root = project.get_project_root()
        local new_cwd = vim.fn.getcwd()
        if new_cwd ~= saved_cwd then
            if M.config.debug then
                vim.notify(
                string.format("[StickyNotes] Directory changed from %s to %s, restoring...", saved_cwd, new_cwd),
                    vim.log.levels.DEBUG)
            end
            vim.cmd("cd " .. vim.fn.fnameescape(saved_cwd))
        end
    end
    return root or saved_cwd
end

function M.get_cache_dir()
    local root = M.get_project_root()
    local cache_base = vim.fn.stdpath("cache") .. "/sticky-notes"
    local project_hash = hash_path(root)
    local cache_dir = cache_base .. "/" .. project_hash
    vim.fn.mkdir(cache_dir, "p")
    local metadata_file = cache_dir .. "/.metadata"
    if vim.fn.filereadable(metadata_file) == 0 then
        local file = io.open(metadata_file, "w")
        if file then
            file:write(root)
            file:close()
        end
    end
    return cache_dir
end

function M.get_notes_list()
    local cache_dir = M.get_cache_dir()
    local notes = {}
    local files = vim.fn.glob(cache_dir .. "/*.md", false, true)
    for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ":t:r")
        table.insert(notes, name)
    end
    table.sort(notes, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a < b
    end)
    return notes
end

function M.get_note_path(name)
    local cache_dir = M.get_cache_dir()
    return cache_dir .. "/" .. name .. ".md"
end

function M.note_exists(name)
    local path = M.get_note_path(name)
    return vim.fn.filereadable(path) == 1
end

function M.close_note()
    if not M.state.win_id or not vim.api.nvim_win_is_valid(M.state.win_id) then
        return
    end
    if M.state.buf_id and vim.api.nvim_buf_is_valid(M.state.buf_id) then
        if vim.bo[M.state.buf_id].modified then
            vim.api.nvim_buf_call(M.state.buf_id, function()
                vim.cmd("silent write")
            end)
        end
    end
    vim.api.nvim_win_close(M.state.win_id, true)
    M.state.win_id = nil
    M.state.buf_id = nil
    M.state.current_note = nil
end

function M.create_window(buf)
    local ui = vim.api.nvim_list_uis()[1]
    local width = M.config.width
    local height = math.floor(ui.height * M.config.height)
    local col = ui.width - width
    local row = math.floor((ui.height - height) / 2)
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",
        border = M.config.border,
        title = " Sticky Notes ",
        title_pos = "center",
    }
    local win = vim.api.nvim_open_win(buf, true, win_opts)
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false
    vim.wo[win].cursorline = true
    vim.wo[win].wrap = true
    vim.wo[win].linebreak = true
    return win
end

function M.open_note(name)
    name = name or "default"
    if M.state.win_id and vim.api.nvim_win_is_valid(M.state.win_id) then
        if M.state.current_note == name then
            vim.api.nvim_set_current_win(M.state.win_id)
            return
        else
            M.close_note()
        end
    end

    local note_path = M.get_note_path(name)
    local buf
    if vim.fn.filereadable(note_path) == 1 then
        buf = vim.fn.bufadd(note_path)
        vim.fn.bufload(buf)
    else
        buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, note_path)
        local initial_content = {
            "# " .. name:gsub("^%l", string.upper):gsub("-", " "),
            "",
        }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial_content)
    end

    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].buflisted = false
    local saved_cwd = vim.fn.getcwd()
    local win = M.create_window(buf)
    vim.api.nvim_win_call(win, function()
        vim.cmd("lcd " .. vim.fn.fnameescape(saved_cwd))
        if M.config.debug then
            vim.notify(string.format("[StickyNotes] Set window-local directory to: %s", saved_cwd), vim.log.levels.DEBUG)
        end
    end)
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_win_set_cursor(win, { line_count, 0 })
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern = tostring(win),
        callback = function()
            if buf and vim.api.nvim_buf_is_valid(buf) then
                if vim.bo[buf].modified then
                    vim.api.nvim_buf_call(buf, function()
                        vim.cmd("silent write")
                    end)
                end
            end
            M.state.win_id = nil
            M.state.buf_id = nil
            M.state.current_note = nil
        end,
        once = true,
    })
    local opts = { buffer = buf, noremap = true, silent = true }
    vim.keymap.set("n", "q", function() M.close_note() end, opts)
    vim.keymap.set("n", "<Esc>", function() M.close_note() end, opts)
    M.state.win_id = win
    M.state.buf_id = buf
    M.state.current_note = name
end

function M.create_note()
    vim.ui.input({ prompt = "Note name: " }, function(input)
        if not input or input == "" then
            return
        end
        local name = input:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
        if name == "" then
            vim.notify("Invalid note name", vim.log.levels.ERROR)
            return
        end
        if M.note_exists(name) then
            vim.notify("Note '" .. name .. "' already exists", vim.log.levels.WARN)
        end
        M.open_note(name)
    end)
end

function M.list_notes()
    local notes = M.get_notes_list()
    if #notes == 0 then
        vim.notify("No notes found. Creating default note...", vim.log.levels.INFO)
        M.open_note("default")
        return
    end
    local ok, snacks = pcall(require, "snacks")
    if not ok or not snacks.picker then
        vim.ui.select(notes, {
            prompt = "Select a note:",
            format_item = function(item)
                return item
            end,
        }, function(choice)
            if choice then
                M.open_note(choice)
            end
        end)
        return
    end
    local items = {}
    for _, note in ipairs(notes) do
        local note_path = M.get_note_path(note)
        table.insert(items, {
            text = note,
            value = note,
            file = note_path,
            pos = { 1, 0 },
        })
    end

    snacks.picker.pick({
        title = "Sticky Notes",
        items = items,
        format = function(item)
            local icon = item.value == "default" and " " or " "
            return {
                { icon,      "String" },
                { " ",       "Normal" },
                { item.text, "Normal" },
            }
        end,
        confirm = function(_, item)
            if item then
                M.open_note(item.value)
            end
        end,
    })
end

function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})

    vim.api.nvim_create_user_command("StickyNotes", function()
        M.open_note("default")
    end, { desc = "Open default sticky note" })

    vim.api.nvim_create_user_command("StickyNotesList", function()
        M.list_notes()
    end, { desc = "List all sticky notes" })

    vim.api.nvim_create_user_command("StickyNotesNew", function()
        M.create_note()
    end, { desc = "Create a new sticky note" })
end

return M
