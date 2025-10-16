-- Telescope Fuzzy Finder Tutorial
return {
	id = "03-telescope-basics",
	name = "Telescope Fuzzy Finder",
	description = "Learn how to use Telescope for quick navigation and search",
	difficulty = "novice",

	steps = {
		{
			title = "Find Files",
			instruction = "Press `<space>ff` to open file finder, explore the results, then close with `<Esc><Esc>` and use `:TutorialNext` to continue",
			hints = {
				"This searches for files in your project",
				"'Your project' is auto-sensed",
				"Type to fuzzy-filter results",
			},
		},
		{
			title = "Search Help Tags",
			instruction = "Press `<space>fh` to search Neovim help, explore the results and use `:TutorialNext` when done",
			hints = {
				"fh stands for 'find help'",
				"This is useful for learning Neovim commands",
				"Try searching for 'telescope' or 'nvim'",
			},
		},
		{
			title = "View Recent Files",
			instruction = "Press `<space>fr` to see recently opened files, explore the results, and use `:TutorialNext` to continue",
			hints = {
				"`fr` stands for 'find recent'",
				"Great for quickly reopening files you were working on",
				"You can use this to quickly return to your previous work",
			},
			-- No validation - manual advancement only
		},
	},
}
