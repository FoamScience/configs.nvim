-- A small Lua script to run LLM-based AI assistants on Neovim Buffers
-- Requires a `tgpt` command to be available in PATH

-- tgpt -c "<code_prompt>" does code-related tasks, and returns code snippets
-- tgpt -q "<prompt>" does general-purpose tasks

local options = require("user.ai.options")

local M = {}

-- Default settings
M.options = options

-- Commands
-- Generic Chat was implemented fine enough with Cody, :CodyChat to get started
-- Code Reviewing
vim.cmd("command! ChatCodeReviewSetFocus lua require('user.ai.review').pick_review_focus()")
vim.cmd("command! ChatCodeReviewPreview lua require('user.ai.review').preview_code_review()")
vim.cmd("command! -range ChatCodeReview lua require('user.ai.review').chat_code_review()")
-- Code Documenting
vim.cmd("command! -range ChatCodeDocument lua require('user.ai.document').chat_code_document()")
vim.cmd("command! ChatCodeDocumentPreview lua require('user.ai.document').preview_code_document()")
-- Code Explaining
--vim.cmd("command! -range ChatCodeExplain lua require('user.ai.explain').chat_code_explain()")
-- Code Discovery
vim.cmd("command! ChatCodeDiscover lua require('user.ai.discover').chat_code_discover(true)")
vim.cmd("command! ChatCodeDiscoverPreview lua require('user.ai.discover').chat_code_discover(false)")
-- Diagnostics Fixing
vim.cmd("command! -range ChatCodeFix lua require('user.ai.diagnose').chat_code_fix()")
vim.cmd("command! ChatCodeFixPreview lua require('user.ai.diagnose').preview_code_fixes()")
-- Text Proofreading
-- Git stuff (suggest commit messages, find similar commits ... etc)
vim.cmd("command! ChatGitCommitMsg lua require('user.ai.git').chat_git_commitmsg()")
vim.cmd("command! ChatGitDiffs lua require('user.ai.git').chat_git_commitdiffs()")

return M
