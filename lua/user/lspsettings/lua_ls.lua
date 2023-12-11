return {
    settings = {
        Lua = {
            format = {
              enable = true,
              indent_style = "space",
              indent_size = 2
            },
            diagnostics = {globals = {"vim", "spec"}},
            runtime = {version = "LuaJIT", special = {spec = "require"}},
            workspace = {
                checkThirdParty = false,
                library = {
                    [vim.fn.expand "$VIMRUNTIME/lua"] = true,
                    [vim.fn.stdpath "config" .. "/lua"] = true
                }
            },
            telemetry = {enable = false}
        }
    }
}
