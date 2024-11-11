local M = {
    'stevearc/overseer.nvim',
    dependencies = {
        "neovim/nvim-lspconfig", -- for root folder...
    }
}

function M.config()
    local util = require("lspconfig.util")
    local overseer = require("overseer")
    overseer.setup({
        task_list = {
            direction = "left",
        }
    })
    local TAG = require("overseer.constants").TAG
    overseer.register_template({
        name = "Compile OpenFOAM libs/solvers",
        tags = { TAG.BUILD },
        builder = function(_)
            return {
                name = "Compile with wmake",
                cmd = { 'wmake' },
                cwd = util.root_pattern("Make")(vim.fn.getcwd()),
            }
        end,
        desc = "with wmake",
        condition = {
            filetype = { "cpp" },
            callback = function(_)
                return os.getenv("FOAM_ETC")
            end
        }
    })
    overseer.register_template({
        name = "Generate compilation db for OpenFOAM libs/solvers",
        tags = { TAG.BUILD },
        builder = function(_)
            return {
                name = "Compile with bear -- wmake",
                cmd = { 'bear', '--', 'wmake' },
                cwd = util.root_pattern("Make")(vim.fn.getcwd()),
            }
        end,
        desc = "with bear",
        condition = {
            filetype = { "cpp" },
            callback = function(_)
                return os.getenv("FOAM_ETC") and vim.fn.executable("bear")
            end
        }
    })
    overseer.register_template({
        name = "Clean OpenFOAM libs/solvers",
        tags = { TAG.CLEAN },
        builder = function(_)
            return {
                name = "Clean with wclean",
                cmd = { 'wclean' },
                cwd = util.root_pattern("Make")(vim.fn.getcwd()),
            }
        end,
        desc = "with wlean",
        condition = {
            filetype = { "cpp" },
            callback = function(_)
                return os.getenv("FOAM_ETC")
            end
        }
    })
end

return M
