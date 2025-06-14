FROM ubuntu:latest

# Install basic packages
RUN apt update && apt install -y python3 python3-pip git curl unzip ripgrep imagemagick
# Install neovim
RUN curl -L https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage -o nvim.appimage
RUN chmod +x nvim.appimage 
RUN ./nvim.appimage --appimage-extract
RUN cp -r squashfs-root/usr/* /usr/ 
RUN rm -rf squashfs-root
# Install nodejs and tree-sitter
WORKDIR /root/.config/nvim
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash \
    && export NVM_DIR="$HOME/.nvm" \
    && [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" \
    && [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" \
    && nvm install v20 \
    && npm install -g tree-sitter-cli
# Install rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
# Set up the configuration
RUN git clone https://github.com/FoamScience/configs.nvim ~/.config/nvim
