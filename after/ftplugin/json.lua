-- Conceal long string values (base64, binary data) in JSON files
-- using treesitter to find string nodes and extmarks for conceal.

local ns = vim.api.nvim_create_namespace("json_conceal_long_strings")
local min_length = 120 -- conceal strings longer than this

local function conceal_long_strings(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "json")
    if not ok or not parser then return end

    local tree = parser:parse()[1]
    if not tree then return end

    local query_ok, query = pcall(vim.treesitter.query.parse, "json", '(string_content) @str')
    if not query_ok then return end

    for _, node in query:iter_captures(tree:root(), bufnr, 0, -1) do
        local sr, sc, er, ec = node:range()
        local text = vim.treesitter.get_node_text(node, bufnr)
        if #text >= min_length then
            vim.api.nvim_buf_set_extmark(bufnr, ns, sr, sc, {
                end_row = er,
                end_col = ec,
                conceal = "#",
            })
        end
    end
end

vim.opt_local.conceallevel = 1

-- Run on buffer load and after changes
conceal_long_strings()
vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    buffer = 0,
    callback = function() conceal_long_strings() end,
})
