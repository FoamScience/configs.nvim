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

  -- Register the xonsh parser with neovim
  vim.treesitter.language.register('xonsh', 'xonsh')

  -- Configure parser for nvim-treesitter main branch
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if ok then
    -- Add xonsh parser configuration
    parsers.xonsh = {
      install_info = {
        url = 'https://github.com/FoamScience/tree-sitter-xonsh',
        files = { 'src/parser.c', 'src/scanner.c' },
        branch = 'main',
        generate_requires_npm = true,
      },
      filetype = 'xonsh',
      maintainers = { '@FoamScience' },
    }
  end

  -- Ensure parser is installed on first xonsh file open
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'xonsh',
    once = true,
    callback = function()
      local ts_ok, ts = pcall(require, 'nvim-treesitter')
      if ts_ok then
        -- Check if parser is installed
        local parser_installed = pcall(vim.treesitter.language.add, 'xonsh')
        if not parser_installed then
          vim.notify('Installing xonsh parser...', vim.log.levels.INFO)
          ts.install({ 'xonsh' })
        end
      end
    end,
  })

  -- Start treesitter highlighting for xonsh files
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'xonsh',
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          pcall(vim.treesitter.start, bufnr, 'xonsh')
        end
      end, 10)
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
