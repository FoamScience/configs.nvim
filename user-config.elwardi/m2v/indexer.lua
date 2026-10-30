-- nvim -l indexer.lua <root> <index dir> <model dir> <opts json>
local root, dir, model_dir, opts = _G.arg[1], _G.arg[2], _G.arg[3], vim.json.decode(_G.arg[4])
vim.opt.rtp:prepend(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))

local model = require("m2v.model").load(model_dir, opts.max_tokens)
require("m2v.index").build(root, dir, model, opts, function(done, total)
    io.stdout:write(("%d %d\n"):format(done, total))
    io.stdout:flush()
end)
