local M = {
  "SmiteshP/nvim-navic",
}

function M.config()
  local icons = require "user.lspicons"
  require("nvim-navic").setup {
    icons = icons.kind,
    highlight = true,
    lsp = {
      auto_attach = true,
    },
    click = true,
    separator = " " .. icons.ui.ChevronRight .. " ",
    depth_limit = 7,
    depth_limit_indicator = "..",
  }
end

return M
