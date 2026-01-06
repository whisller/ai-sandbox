FROM docker/sandbox-templates:claude-code

USER root

# Install openssh-client for SSH agent access
RUN apt-get update && \
    apt-get install -y openssh-client && \
    rm -rf /var/lib/apt/lists/*

# Allow agent user to fix socket permissions without password
RUN echo "agent ALL=(ALL) NOPASSWD: /bin/chmod" >> /etc/sudoers

# Create entrypoint script that reads git config from host
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Colors for output\n\
GREEN='\''\033[0;32m'\''\n\
YELLOW='\''\033[1;33m'\''\n\
NC='\''\033[0m'\'' # No Color\n\
\n\
echo -e "${GREEN}Setting up Claude Code environment...${NC}"\n\
\n\
# Read git config from mounted host gitconfig\n\
if [ -f /host-gitconfig ]; then\n\
    USER_NAME=$(git config -f /host-gitconfig user.name 2>/dev/null || true)\n\
    USER_EMAIL=$(git config -f /host-gitconfig user.email 2>/dev/null || true)\n\
    \n\
    if [ -n "$USER_NAME" ]; then\n\
        git config --global user.name "$USER_NAME"\n\
        echo -e "${GREEN}✓${NC} Git user.name: $USER_NAME"\n\
    fi\n\
    \n\
    if [ -n "$USER_EMAIL" ]; then\n\
        git config --global user.email "$USER_EMAIL"\n\
        echo -e "${GREEN}✓${NC} Git user.email: $USER_EMAIL"\n\
    fi\n\
else\n\
    echo -e "${YELLOW}⚠${NC} .gitconfig not found, git user not configured"\n\
fi\n\
\n\
# Setup SSH commit signing if SSH_AUTH_SOCK is available\n\
if [ -S "$SSH_AUTH_SOCK" ]; then\n\
    sudo chmod 666 "$SSH_AUTH_SOCK" 2>/dev/null || true\n\
    \n\
    if ssh-add -L >/dev/null 2>&1; then\n\
        KEY=$(ssh-add -L 2>/dev/null | head -n1 || true)\n\
        if [ -n "$KEY" ]; then\n\
            git config --global gpg.format ssh\n\
            git config --global commit.gpgsign true\n\
            git config --global user.signingkey "$KEY"\n\
            KEY_NAME="${KEY##* }"\n\
            echo -e "${GREEN}✓${NC} SSH signing configured with key: $KEY_NAME"\n\
        fi\n\
    else\n\
        echo -e "${YELLOW}⚠${NC} SSH agent not accessible"\n\
    fi\n\
else\n\
    echo -e "${YELLOW}⚠${NC} SSH_AUTH_SOCK not set"\n\
fi\n\
\n\
echo -e "${GREEN}Environment ready!${NC}"\n\
echo ""\n\
\n\
exec "$@"' > /usr/local/bin/docker-entrypoint.sh && chmod +x /usr/local/bin/docker-entrypoint.sh

USER agent
# WORKDIR is set by docker-compose to match host path (docker sandbox behavior)

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
# Keep container running - claude is started via exec
CMD ["tail", "-f", "/dev/null"]
