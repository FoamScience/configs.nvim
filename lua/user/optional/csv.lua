local M = {
	"cameron-wags/rainbow_csv.nvim",
	event = "VeryLazy",
    ft = {
        'csv',
        'tsv',
        'csv_semicolon',
        'csv_whitespace',
        'csv_pipe',
        'rfc_csv',
        'rfc_semicolon'
    },
    cmd = {
        'RainbowDelim',
        'RainbowDelimSimple',
        'RainbowDelimQuoted',
        'RainbowMultiDelim'
    }
}

function M.config()
	require("rainbow_csv").setup {}
end

return M
