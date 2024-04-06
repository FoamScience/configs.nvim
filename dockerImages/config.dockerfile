FROM ubuntu:latest

# Install basic packages
RUN apt update && apt install -y python3 python3-pip git curl unzip ripgrep
# Install neovim
RUN curl -L https://github.com/neovim/neovim/releases/download/v0.9.5/nvim.appimage -o nvim.appimage
RUN chmod +x nvim.appimage 
RUN ./nvim.appimage --appimage-extract
RUN cp -r squashfs-root/usr/* /usr/ 
RUN rm -rf squashfs-root
# Install nodejs and tree-sitter
WORKDIR /root/.config/nvim
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && export NVM_DIR="$HOME/.nvm" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" \
    && nvm install v18 \
    && npm install -g tree-sitter-cli
# Install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
# Install AI chatbot
RUN curl -L https://github.com/aandrew-me/tgpt/releases/download/v2.7.3/tgpt-linux-amd64 -o /usr/local/bin/chat
RUN chmod +x /usr/local/bin/chat
# Install the configuration
RUN git clone https://github.com/FoamScience/configs.nvim ~/.config/nvim
