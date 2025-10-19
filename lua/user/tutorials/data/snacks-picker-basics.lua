-- Snacks.picker Fuzzy Finder Tutorial
return {
	id = "03-snacks-picker-basics",
	name = "Fuzzy Finder",
	description = "Master the fuzzy finder for lightning-fast navigation and search",
	difficulty = "novice",

	steps = {
		{
			title = "Find Files - Basic Usage",
			instruction = "Press `<space>ff` to open file finder, type some characters to filter, then close with `<Esc>` and use `:TutorialNext`",
			hints = {
				"This searches for files in your project root",
				"The project root is auto-detected (looks for .git, etc.)",
				"Type to fuzzy-filter results - you don't need exact matches!",
				"Try typing partial names like 'init' or 'conf'",
			},
		},
		{
			title = "View Recent Files",
			instruction = "Press `<space>fr` to see recently opened files (oldfiles), then close and use `:TutorialNext`",
			hints = {
				"`fr` stands for 'find recent'",
				"This shows files you've opened before, even if not in current project",
				"Great for quickly reopening files from yesterday's work",
				"Files are sorted by most recently used",
			},
		},
		{
			title = "Search Help Documentation",
			instruction = "Press `<space>fh` to search Neovim help, type 'window' to search help topics, then close and use `:TutorialNext`",
			hints = {
				"All of Neovim's documentation is searchable!",
				"Try searching for 'window', 'buffer', 'motion'",
				"This is the best way to learn Neovim features",
				"Select an entry to open the help page",
			},
		},
		{
			title = "Browse Keymaps",
			instruction = "Press `<space>fk` to browse all available keymaps, search for 'picker' or 'find', then close and use `:TutorialNext`",
			hints = {
				"This shows ALL keymaps configured in Neovim",
				"Great for discovering what shortcuts are available",
				"You can search by key combo or description",
				"Look for patterns like '<leader>f' to see all find commands",
			},
		},
		{
			title = "Resume last search",
			instruction = "Press `<space>fl` to resume your last picker search, then close and use `:TutorialNext`",
			hints = {
				"`fl` stands for 'find last'",
				"This reopens the last picker with your previous search",
				"Super useful for continuing interrupted work",
				"Your search terms and position are preserved!",
			},
		},
		{
			title = "Colorscheme Picker",
			instruction = "Press `<space>fc` to browse colorschemes, try selecting different ones with `<CR>`, then close and use `:TutorialNext`",
			hints = {
				"You can preview colorschemes in real-time!",
				"Press Enter on a colorscheme to apply it",
				"Changes are immediate but not saved",
				"Great for trying out different color schemes",
			},
		},
		{
			title = "Git Branch Navigation",
			instruction = "Press `<space>fb` to view git branches (if in a git repo), then close and use `:TutorialNext`",
			hints = {
				"Shows all git branches in your repository",
				"You can switch branches by selecting one",
				"Only works if you're in a git repository",
				"Local and remote branches are both shown",
			},
		},
		{
			title = "Advanced: Toggles and Options",
			instruction = "Open file finder `<space>ff`, then press `<alt-h>` to toggle hidden files, `<alt-i>` for ignored files. Close and use `:TutorialNext`",
			hints = {
				"`<alt-h>` toggles showing hidden files (like .gitignore)",
				"`<alt-i>` toggles showing ignored files (git-ignored)",
				"`<alt-p>` toggles the preview window",
				"`<alt-m>` maximizes/restores the picker window",
				"These toggles work in most pickers!",
			},
		},
		{
			title = "Preview Window Navigation",
			instruction = "Open `<space>ff`, select a file, use `<C-f>` and `<C-b>` to scroll the preview, then close and use `:TutorialNext`",
			hints = {
				"The preview shows file contents on the right",
				"`<C-f>` scrolls preview forward (down)",
				"`<C-b>` scrolls preview backward (up)",
				"This lets you peek at files before opening them!",
			},
		},
		{
			title = "Multiple File Selection",
			instruction = "Open `<space>ff`, press `<Tab>` to select multiple files, then `<CR>` to open all. Use `:TutorialNext` after",
			hints = {
				"Press `<Tab>` to toggle selection (● selected, ○ unselected)",
				"Press `<S-Tab>` to select and move up",
				"Press `<C-a>` to select all visible items",
				"Selected items are marked with ●",
				"All selected files open when you press Enter!",
			},
		},
		{
			title = "Registers and Clipboard",
			instruction = "Press `<space>fR` to view all registers, see what's in your clipboard and yank history, then close and use `:TutorialNext`",
			hints = {
				"Registers store copied/deleted text in Neovim",
				"The \" register is your default yank/delete",
				"The + register is your system clipboard",
				"Named registers (a-z) are for manual storage",
				"Select a register to paste its contents!",
			},
		},
		{
			title = "Commands Palette",
			instruction = "Press `<space>fC` to browse all available commands, search for 'Lazy', then close and use `:TutorialNext`",
			hints = {
				"Lists all Ex commands available in Neovim",
				"Includes built-in and plugin commands",
				"Great way to discover new features",
				"Select a command to execute it!",
			},
		},
		{
			title = "Commands history",
			instruction = "Press `<space>f:` to browse your recent commands, then close and use `:TutorialNext`",
			hints = {
				"This can be more useful then :<up><up>... etc",
			},
		},
		{
			title = "Highlights Inspector",
			instruction = "Press `<space>fH` to browse all highlight groups, search for 'String' or 'Comment', then close and use `:TutorialNext`",
			hints = {
				"Highlight groups control colors in Neovim",
				"Useful for customizing your colorscheme",
				"Shows the actual colors next to group names",
				"Try searching for 'Diagnostic', 'Diff', or 'Git'",
			},
		},
		{
			title = "Congratulations!",
			instruction = "You've mastered Snacks.picker basics! Practice these shortcuts in your daily workflow. Use `:TutorialQuit` when ready.",
			hints = {
				"Most used: <space>ff (files), <space>fs (search), <space>fB (buffers)",
				"Remember: fuzzy matching saves time - 'usn' finds 'user/snacks'",
				"Use <Tab> for multi-select, <alt-h/i> for toggles",
				"The ivy layout puts the picker at bottom for easy access",
				"Press ? in any picker to see all available keybindings!",
			},
		},
	},
}
