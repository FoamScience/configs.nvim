-- options table holds configuration for the AI chat system.
return {
	source = "AI.chat",
	cmd = "tgpt",
	code_args = {
		"-c", -- this one needs to be last
	},
	general_args = {
		"-q",
	},
	review = {
		count = 5,
		edit = true,
		focus = "No particular",
		sign = "dots4",
		code_args = {
			"-provider",
			"opengpts", -- better for returning accurate text edits
            "-preprompt",
            "Your are an experienced code reviewer. Give JSON output with text edits which follow LSP conventions."
		},
	},
	document = {
		edit = true,
		style = "a common style for my language",
		sign = "dots8",
		code_args = {
			"-provider",
			"phind", -- better for returning accurate text edits
		},
	},
	diagnose = {
		edit = true,
		sign = "dots4",
		code_args = {
			"-provider",
			"opengpts", -- better for returning accurate text edits
            "-preprompt",
            "Your are an expert code debugger. Give JSON output with text edits which follow LSP conventions."
		},
	},
	discover = {
		sign = "dots4",
		code_args = {
			"-provider", "groq",
			"-key", vim.env.GROQ_API_KEY,
			"-model", "mixtral-8x7b-32768",
		},
	},
	git = {
		count = 3,
		sign = "dots8",
		code_args = {
			"-provider", "groq",
			"-key", vim.env.GROQ_API_KEY,
			"-model", "mixtral-8x7b-32768",
		},
	},
}
