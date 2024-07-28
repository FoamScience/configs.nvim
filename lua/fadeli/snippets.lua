local M = {}

if not pcall(require, 'luasnip') then
    return M
end

local ls = require 'luasnip'
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local d = ls.dynamic_node

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
            t(print_statement .. '"=== DEBUG (' .. filename .. ':' .. line .. ') at `' .. next_line .. '` ===" << std::endl;')
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

M.config = function()
    ls.add_snippets("all", snippets)
end

return M
