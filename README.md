# ai-sandbox

A zero-configuration Docker Compose setup that mimics [docker sandbox](https://docs.docker.com/ai/sandboxes/) behavior.

This allows your Claude AI agents to run in a fully isolated environment.

One persistent container per workspace with automatic git configuration and SSH commit signing.

## Features

- **Docker Sandbox Behavior**: One container per workspace, reused across sessions
- **Multiple Terminal Support**: Open multiple tabs, each runs separate Claude instance
- **Persistent State**: Installed packages and files persist across sessions
- **Zero Configuration**: Automatically reads git config from your host system
- **SSH Commit Signing**: Auto-configured with your SSH agent (macOS or 1Password)
- **Shared Filesystem**: All terminals share the same workspace
- **Python Variant**: Optional Python image with uv, poetry, ruff, pytest, mypy

## Prerequisites

- Docker Desktop 4.50+ (for SSH agent forwarding)
- macOS or Linux
- Git configured on host (`git config --global user.name` and `user.email`)
- SSH keys available via SSH agent

## Quick Start

### 1. Build the image

```bash
cd ~/Sites/ai-sandbox
./ai-sandbox --build           # builds and runs ai-sandbox:claude
./ai-sandbox python --build    # builds and runs ai-sandbox:python
```

### 2. Configure workspace path

**Option A:** Set in shell config (recommended):
```bash
# Add to ~/.zshrc or ~/.bashrc
export AI_SANDBOX_WORKSPACE_PATH=/your/workspace/path
alias ai-sandbox='~/Sites/ai-sandbox/ai-sandbox'
```

**Option B:** Use `.env` file:
```bash
cp .env.example .env
# Edit .env and set AI_SANDBOX_WORKSPACE_PATH
```

Reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 3. Run Claude

```bash
ai-sandbox
```

That's it!

## How It Works

### Docker Sandbox Model

Just like `docker sandbox`, this setup maintains **one container per workspace**:

1. **First time**: Creates a new container
2. **Subsequent runs**: Reuses the existing container
3. **State persists**: npm packages, files, changes all persist

### Multiple Terminal Tabs

Open multiple terminal tabs and run `ai-sandbox` in each:

```bash
# Terminal Tab 1
ai-sandbox
> "install express and create a server"

# Terminal Tab 2 (reuses same container)
ai-sandbox
> "create tests for the server"
# Can see express packages installed in Tab 1

# Terminal Tab 3
ai-sandbox
> "update the README"
```

All tabs:
- Share the same filesystem
- Share installed packages
- Run separate Claude processes
- See each other's changes in real-time

## Usage

### Starting Claude

```bash
# From any terminal
ai-sandbox
```

The script automatically:
- Creates container if it doesn't exist
- Reuses existing container if running
- Starts new Claude instance in that container

### Multiple Sessions

```bash
# Terminal 1
ai-sandbox

# Terminal 2 (new tab)
ai-sandbox  # Connects to same container

# Terminal 3 (new tab)
ai-sandbox  # Connects to same container
```

### Stopping/Resetting

To remove the container and start fresh:

```bash
cd ~/Sites/ai-sandbox
docker-compose down
```

Next `ai-sandbox` command will create a new container.

## Configuration

### Workspace Path

Set via environment variable:

```bash
# Option 1: Set for single session
AI_SANDBOX_WORKSPACE_PATH=/your/workspace/path ai-sandbox

# Option 2: Set in your shell config (~/.zshrc)
export AI_SANDBOX_WORKSPACE_PATH=/your/workspace/path

# Option 3: Create .env file
cp .env.example .env
# Edit AI_SANDBOX_WORKSPACE_PATH in .env
```

### SSH Key Selection

Set environment variable to use specific SSH key:

```bash
export AI_SANDBOX_SSH_KEY_NAME="[Docker Sandbox] GitHub"
ai-sandbox
```

### Git Configuration

Git config is automatically read from your `~/.gitconfig`. To verify:

```bash
# Inside container
git config --global --list
```

### Persistent Authentication

Claude authentication is stored in a Docker named volume (`ai-sandbox-config`) that persists across container restarts:

```bash
# On first run, authenticate via browser
ai-sandbox  # Opens browser for OAuth authentication

# Subsequent runs use the persisted token
ai-sandbox  # No authentication needed

# To reset authentication (force re-login)
docker volume rm ai-sandbox_ai-sandbox-config
```

The volume maps to `/home/agent/.config` inside the container, storing:
- Claude authentication tokens
- Claude settings and preferences
- Any other config files

## Installed Tools

Based on official `docker/sandbox-templates:claude-code` image with:

- **Claude Code**: Pre-installed from official image
- **Languages**: Python 3, Node.js, npm
- **Version Control**: git
- **Build Tools**: gcc, make, build-essential
- **Databases**: postgresql-client, sqlite3
- **Network**: curl, wget, socat, netcat
- **Utilities**: jq, vim, nano, tree, htop, zip, unzip

## Python Variant

A Python-focused image is available that builds on top of `ai-sandbox:claude` and adds:

- **uv** — fast Python package manager
- **poetry** — dependency management
- **ruff** — linter/formatter
- **pytest** + **pytest-cov** — testing
- **mypy** — type checking

### Build the Python image

```bash
./ai-sandbox python --build
```

## SSH Signing Setup

Works automatically with both macOS native SSH agent and 1Password through Docker Desktop's `/run/host-services/ssh-auth.sock`.

### macOS Native SSH Agent

Ensure your SSH keys are added to the keychain:
```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

### 1Password

1. Enable SSH agent in 1Password settings
2. Generate or import SSH keys in 1Password
3. Optional: Set AI_SANDBOX_SSH_KEY_NAME environment variable
   ```bash
   export AI_SANDBOX_SSH_KEY_NAME="[Docker Sandbox] GitHub"
   ```

## Troubleshooting

### SSH Signing Not Working

Check SSH agent inside container:

```bash
docker exec ai-sandbox ssh-add -L
```

Should list your SSH keys. If not:
- Ensure Docker Desktop SSH forwarding is enabled
- For 1Password: enable SSH agent in settings
- Restart Docker Desktop

### Git Config Not Set

Check inside container:

```bash
docker exec ai-sandbox git config --global --list
```

Should show `user.name` and `user.email`. If not:
- Verify `git config --global user.name` works on host
- Check that `~/.gitconfig` exists on host
- Rebuild: `docker-compose build`

### Container Not Reusing

If each `ai-sandbox` command creates a new container:

```bash
# Check for existing container
docker ps -a | grep ai-sandbox

# Remove old containers
docker rm -f ai-sandbox

# Try again
ai-sandbox
```

### Multiple Claude Instances Conflicting

If Claude instances interfere with each other, they might be trying to modify the same files. This is expected behavior - coordinate work between terminals or use different directories.

## Architecture

- **Base Image**: `docker/sandbox-templates:claude-code`
- **Container Model**: One container per workspace (persists across sessions)
- **User**: `agent` (non-root for security)
- **Workspace**: Mounted at same path as host (docker sandbox behavior)
- **SSH Agent**: Forwarded from host via Docker Desktop
- **Git Config**: Read from host's `~/.gitconfig` at startup
- **State**: Persists in container until explicitly removed

## Files

```
ai-sandbox/
├── Dockerfile.claude            # Base image (git config + SSH signing)
├── Dockerfile.python            # Python variant (FROM ai-sandbox:claude)
├── docker-compose.yml           # Base configuration
├── docker-compose.ssh.yml       # SSH agent forwarding
├── docker-compose.python.yml    # Python variant override
├── ai-sandbox                   # Wrapper script (mimics docker sandbox)
├── .gitignore
└── README.md
```

## Security

- Container runs as non-root user (`agent`)
- Only workspace directory is mounted
- `${HOME}/.gitconfig mounted read-only (for .gitconfig only)
- SSH keys stay on host, only agent socket forwarded
- sudo limited to `chmod` command only

## Advanced Usage

### Custom Dockerfile Changes

After modifying the Dockerfile:

```bash
docker-compose down  # Remove old container
docker-compose build  # Rebuild image
ai-sandbox  # Start with new image
```

### Environment Variables

Pass additional environment variables:

```bash
# Edit docker-compose.ssh.yml and add:
environment:
  - MY_VAR=value
```

### Additional Volumes

Mount additional directories by editing `docker-compose.yml`:

```yaml
volumes:
  - ${AI_SANDBOX_WORKSPACE_PATH}:${AI_SANDBOX_WORKSPACE_PATH}
  - /path/to/other/dir:/mnt/other:ro
```

## Tips

1. **One workspace, one container**: The container name is `ai-sandbox`, so only one workspace can be active. For multiple workspaces, modify `docker-compose.yml` to use different container names.

2. **Fresh start**: To completely reset:
   ```bash
   docker-compose down -v  # Remove volumes too
   docker-compose build --no-cache
   ai-sandbox
   ```
