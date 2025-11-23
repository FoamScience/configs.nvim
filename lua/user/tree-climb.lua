-- Tree-sitter AST navigation
-- Navigate between siblings in the syntax tree

local M = {}

local function get_node_at_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local ok, node = pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row, col } })
    if not ok or not node then
        vim.notify("No treesitter node at cursor", vim.log.levels.WARN)
        return nil
    end
    return node
end

local function move_to_node(node)
    if not node then return end
    local start_row, start_col, _, _ = node:range()
    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
end

function M.goto_next_sibling()
    local node = get_node_at_cursor()
    if not node then return end
    local current = node
    while current do
        local sibling = current:next_sibling()
        if sibling then
            move_to_node(sibling)
            return
        end
        current = current:parent()
    end
    vim.notify("No next sibling found", vim.log.levels.INFO)
end

function M.goto_prev_sibling()
    local node = get_node_at_cursor()
    if not node then return end
    local current = node
    while current do
        local sibling = current:prev_sibling()
        if sibling then
            move_to_node(sibling)
            return
        end
        current = current:parent()
    end
    vim.notify("No previous sibling found", vim.log.levels.INFO)
end

function M.select_current_node()
    local node = get_node_at_cursor()
    if not node then return end
    local start_row, start_col, end_row, end_col = node:range()
    vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
    vim.cmd('normal! v')
    vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col - 1 })
end

function M.setup()
    local opts = { noremap = true, silent = true }

    vim.keymap.set('n', '<M-n>', M.goto_next_sibling,
        vim.tbl_extend('force', opts, { desc = 'Tree: Next sibling' }))
    vim.keymap.set('n', '<M-N>', M.goto_prev_sibling,
        vim.tbl_extend('force', opts, { desc = 'Tree: Previous sibling' }))
    vim.keymap.set('n', '<M-v>', M.select_current_node,
        vim.tbl_extend('force', opts, { desc = 'Tree: Select node' }))
end

M.setup()

return M
