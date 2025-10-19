#!/usr/bin/env bash

set -e
rm ./screenshots/*png
SOCKET="/tmp/nvimsocket"

kitty --start-as=maximized nvim --listen "$SOCKET" init.lua README.md&
sleep 3
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


uvx --from=neovim-remote nvr --remote-send ','
sleep 1
scrot -f screenshots/arrow.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ':TodoQuickFix<CR>'
sleep 1
scrot -f screenshots/todos.png
uvx --from=neovim-remote nvr --remote-send '<Esc><Esc>'

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

uvx --from=neovim-remote nvr --remote-send ' l'
sleep 1
scrot -f screenshots/lsp1.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send 'g'
sleep 1
scrot -f screenshots/lsp2.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ' g'
sleep 1
scrot -f screenshots/git.png
uvx --from=neovim-remote nvr --remote-send '<Esc>'

uvx --from=neovim-remote nvr --remote-send ':CodeCompanionChat<CR>'
sleep 1
scrot -f screenshots/ai.png
uvx --from=neovim-remote nvr --remote-send ':bd<CR>'

uvx --from=neovim-remote nvr --remote-send ':qa!<CR>'
