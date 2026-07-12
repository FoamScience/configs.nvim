-- cmake-tools.nvim — CMake configure/build/run from inside nvim. Soft-links the
-- generated compile_commands.json to the project root, which is exactly what the
-- clangd config here keys off (root_markers = { "compile_commands.json", ... }).
-- Keymaps under <leader>m (group in whichkey.lua). <leader>md needs nvim-dap.
return {
    "Civitasv/cmake-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    ft = { "c", "cpp", "cmake" },
    cmd = {
        "CMakeGenerate", "CMakeBuild", "CMakeRun", "CMakeDebug",
        "CMakeSelectBuildTarget", "CMakeSelectLaunchTarget",
        "CMakeSelectBuildType", "CMakeClean",
    },
    keys = {
        { "<leader>mg", "<cmd>CMakeGenerate<cr>",           desc = "Generate (configure)" },
        { "<leader>mb", "<cmd>CMakeBuild<cr>",              desc = "Build" },
        { "<leader>mr", "<cmd>CMakeRun<cr>",                desc = "Run" },
        { "<leader>md", "<cmd>CMakeDebug<cr>",              desc = "Debug (needs nvim-dap)" },
        { "<leader>mt", "<cmd>CMakeSelectBuildTarget<cr>",  desc = "Select build target" },
        { "<leader>ml", "<cmd>CMakeSelectLaunchTarget<cr>", desc = "Select launch target" },
        { "<leader>my", "<cmd>CMakeSelectBuildType<cr>",    desc = "Select build type" },
        { "<leader>mc", "<cmd>CMakeClean<cr>",              desc = "Clean" },
    },
    opts = {
        cmake_command = "cmake",
        cmake_build_directory = "build/${variant:buildType}",
        cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
        cmake_soft_link_compile_commands = true,
    },
}
