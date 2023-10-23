local M = {
	"phaazon/hop.nvim",
	event = "BufEnter",
}

function M.config()
    require'hop'.setup {
        keys = 'etovxqpdygfblzhckisuran',
    }
end

return M
