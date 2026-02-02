-- Xonsh tree-sitter support (against nvim-treesitter main branch)
local M = {}

function M.setup()
  -- Register xonsh filetype
  vim.filetype.add({
    extension = {
      xsh = 'xonsh',
      xonshrc = 'xonsh',
    },
    filename = {
      ['.xonshrc'] = 'xonsh',
      ['xonshrc'] = 'xonsh',
    },
  })

  -- Register the xonsh parser
  vim.treesitter.language.register('xonsh', 'xonsh')

  -- Add parser install info for :TSInstall
  local ok, install = pcall(require, 'nvim-treesitter.install')
  if ok and install.compilers then
    -- Define parser metadata (from GitHub)
    install.parsers.xonsh = {
      url = 'https://github.com/FoamScience/tree-sitter-xonsh',
      files = { 'src/parser.c', 'src/scanner.c' },
    }
  end

  -- Start treesitter for xonsh files
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'xonsh',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          pcall(vim.treesitter.start, bufnr, 'xonsh')
        end
      end, 1)
    end,
  })

  -- Set comment string for xonsh
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'xonsh',
    callback = function()
      vim.bo.commentstring = '# %s'
    end,
  })
end

return M
