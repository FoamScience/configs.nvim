local M = {
    ai = {
        language = "German",          -- language that the AI reposnds in
        model = "openai/gpt-oss-20b", -- default LLM model to use
        send_code = function() return true end, -- can skip specific root folders here
    },
    neorg = {
        workspaces = {
            tasks = "~/notes/tasks",
            Meshless = "~/notes/Meshless",
            OpenFOAMOpt = "~/notes/OpenFOAMOpt",
            UnitTesting = "~/notes/UnitTesting",
            TGradientAlongSolidificationPaths = "~/notes/TGradientAlongSolidificationPaths",
            HipJointML = "~/notes/HipJointML",
        },
        default_workspace = "tasks",
    },
}

return M
