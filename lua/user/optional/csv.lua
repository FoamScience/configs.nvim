local M = {
	--"theKnightsOfRohan/csvlens.nvim",
	--dependencies = {
	--	"akinsho/toggleterm.nvim",
	--},
	"hat0uma/csvview.nvim",
	cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
}

function M.config()
	--require("csvlens").setup({})
	require("csvview").setup({
		keymaps = {
			textobject_field_inner = { "if", mode = { "o", "x" } },
			textobject_field_outer = { "af", mode = { "o", "x" } },
		}
	})
end

return M
