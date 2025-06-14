local M = {
    'chomosuke/typst-preview.nvim',
    ft = 'typst',
    version = '1.*',
    opts = {},
}

function M.config()
    require("typst-preview").setup{
        open_cmd = 'firefox %s -P typst-preview --class typst-preview',
        dependencies_bin = {
            ['tinymist'] = 'tinymist'
        }
    }
end

return M
