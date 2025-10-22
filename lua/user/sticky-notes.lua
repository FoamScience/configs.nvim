local M = {
    dir = vim.fn.stdpath("config") .. "/lua/stickynotes",
    name = "stickynotes",
    dependencies = {
        "ahmedkhalf/project.nvim",
        "folke/snacks.nvim",
    },
    cmd = {
        "StickyNotes",
        "StickyNotesList",
        "StickyNotesNew",
    },
}

function M.config()
    require("stickynotes").setup({})
end

return M
