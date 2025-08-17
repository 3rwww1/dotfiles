FROM mcr.microsoft.com/devcontainers/base:debian

# Install minimal deps to run the dotfiles installer
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git stow zsh curl ca-certificates sudo locales \
    zsh-autosuggestions zsh-syntax-highlighting \
    && rm -rf /var/lib/apt/lists/*

# Set locale to avoid any locale warnings
RUN locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# Create a non-root user (vscode) if not present
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
RUN if ! id -u $USERNAME >/dev/null 2>&1; then \
      groupadd --gid $USER_GID $USERNAME && \
      useradd -s /usr/bin/zsh --uid $USER_UID --gid $USER_GID -m $USERNAME && \
      echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
      chmod 0440 /etc/sudoers.d/$USERNAME ; \
    fi

USER $USERNAME
WORKDIR /workspaces

# Add mise shims to PATH for subsequent commands
ENV PATH=/home/$USERNAME/.local/share/mise/shims:$PATH

# Copy repo and run installer (Linux path)
COPY --chown=$USERNAME:$USERNAME . /workspaces/dotfiles
WORKDIR /workspaces/dotfiles
RUN ./install.sh

CMD ["/usr/bin/zsh"]
