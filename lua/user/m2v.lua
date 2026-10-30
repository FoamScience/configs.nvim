-- Semantic code search on model2vec static embeddings, run in LuaJIT: treesitter
-- chunks indexed by a background `nvim -l`, fused with ripgrep matches.
return {
    "FoamScience/m2v.nvim",
    main = "m2v",
    opts = {},
    keys = {
        {
            "<leader>fS",
            function()
                require("m2v.picker").search_prompt()
            end,
            desc = "Semantic search (m2v)",
        },
        {
            "<leader>fL",
            function()
                require("m2v.picker").live()
            end,
            desc = "Semantic search live (m2v)",
        },
    },
}
