local M = {
    "hadronized/hop.nvim",
    cmd = {"HopWord", "HopLine", "HopeChar1", "HopChar2", "HopAnywhere"},
    event = "VeryLazy",
}

function M.config()
    require 'hop'.setup {
        keys = 'etovxqpdygfblzhckisuran',
    }
end

return M
