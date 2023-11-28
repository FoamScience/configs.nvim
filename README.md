This my minimal, clutter-free, less-than-a-million-keymaps Neovim configuration for day-to-day programming.

> Best used with Kitty terminal (or Alacritty if you prefer that) which runs a powerline font (or at least,
> a font that supports ligatures)

Here are a few programming languages I usually write in:
- C++/C (and OpenFOAM code)
- Python, Lua as scripting languages
- HTML, CSS, JavaScript for web development
- Markdown for writing READMEs and other documentation, LATEX for academic writing
- GdScript, GLSL for game development
- Obviously, Bash for shell scripting

Want to get started? -> Press `<space>`

In particular, this configuration will never support the following features:
- Debugging. Not an editor's job, use GDB and the like.
- Auto-formatting, because trying to auto-format C++ is a pain!

## Requirements

- Neovim 0.9+, Node, Python 3 and Rust installed
- A terminal with ligature support (**Kitty**, Alacritty, etc.)
  - For kitty, I like to set (after installing Comic Code Ligatures, Font Awesome and Symbols Nerd Font Mono):
    ```
    font_family      ComicCodeLigatures
    symbol_map U+f000-U+f0e2 fontawesome
    symbol_map U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0D4,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6AA,U+E700-U+E7C5,U+EA60-U+EBEB,U+F000-U+F2E0,U+F300-U+F32F,U+F400-U+F4A9,U+F500-U+F8FF,U+F0001-U+F1AF0 Symbols Nerd Font Mono
    ```
- An OpenAI-like AI agent in the form of a CLI binary called `chat` 
