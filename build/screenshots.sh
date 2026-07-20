#!/usr/bin/env bash

set -e
rm ./screenshots/*png
SOCKET="/tmp/nvimsocket"

# scrot reads the X root window, which is empty under a Wayland compositor.
# Render into a headless X server instead so captures work on X11 and Wayland.
export DISPLAY=:99
unset WAYLAND_DISPLAY
Xvfb "$DISPLAY" -screen 0 1600x1000x24 &
XVFB_PID=$!
trap 'kill "$XVFB_PID" 2>/dev/null' EXIT
sleep 2

# no window manager on Xvfb, so size the window explicitly instead of maximizing
kitty -o remember_window_size=no -o initial_window_width=1600 -o initial_window_height=1000 \
    nvim --listen "$SOCKET" init.lua README.md&
sleep 8
scrot -f screenshots/nvim.png

uvx --from=neovim-remote nvr --remote-send ' '
sleep 1
scrot -f screenshots/whichkey.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ':NvimTreeToggle<CR>'
sleep 1
scrot -f screenshots/tree.png
uvx --from=neovim-remote nvr --remote-send ':NvimTreeToggle<CR>'

uvx --from=neovim-remote nvr --remote-send ' ff'
sleep 1
scrot -f screenshots/ui1.png
uvx --from=neovim-remote nvr --remote-send '<Esc><Esc>'

uvx --from=neovim-remote nvr --remote-send ':T<Tab>'
sleep 1
scrot -f screenshots/ui2.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ':TodoQuickFix<CR>'
sleep 1
scrot -f screenshots/todos.png
uvx --from=neovim-remote nvr --remote-send ':q<CR>'

uvx --from=neovim-remote nvr --remote-send 'gg0'
uvx --from=neovim-remote nvr --remote-send 's'
sleep 1
scrot -f screenshots/flash1.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send 'gg0'
uvx --from=neovim-remote nvr --remote-send 'sv'
sleep 1
scrot -f screenshots/flash2.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ' nn'
sleep 1
scrot -f screenshots/lsp-navigation.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

# park the cursor on vim.loader.enable() so the LSP shots have a symbol to work with
uvx --from=neovim-remote nvr --remote-send ':2<CR>0wwww'
uvx --from=neovim-remote nvr --remote-send 'K'
sleep 2
scrot -f screenshots/lsp2.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ' xl'
sleep 3
scrot -f screenshots/lsp1.png
uvx --from=neovim-remote nvr --remote-send ' xl'

# diffview opens in its own tab, so close the tab rather than trusting a toggle
uvx --from=neovim-remote nvr --remote-send ' gdv'
sleep 4
scrot -f screenshots/git.png
uvx --from=neovim-remote nvr --remote-send ':DiffviewClose<CR>:tabonly<CR>'

# oil replaces the buffer in place; jump back to init.lua explicitly afterwards
uvx --from=neovim-remote nvr --remote-send ':e .<CR>'
sleep 2
scrot -f screenshots/oil.png
uvx --from=neovim-remote nvr --remote-send ':b1<CR>'

uvx --from=neovim-remote nvr --remote-send ':b1<CR>gg0VG'
uvx --from=neovim-remote nvr --remote-send ' rr'
sleep 2
scrot -f screenshots/refactor.png
uvx --from=neovim-remote nvr --remote-send '<Esc><Esc>'

uvx --from=neovim-remote nvr --remote-send ':b1<CR>Govim.'
sleep 3
scrot -f screenshots/completion.png
uvx --from=neovim-remote nvr --remote-send '<Esc>u'

uvx --from=neovim-remote nvr --remote-send ':qa!<CR>' || true
