local M = {
	"whiteinge/diffconflicts",
    event = {"BufReadPre", "BufNewFile"},
}
M.config = function()
    --require("diffconflicts").setup{}
end

return M
