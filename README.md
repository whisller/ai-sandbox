# Claude Code Docker Environment

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

## Prerequisites

- Docker Desktop 4.50+ (for SSH agent forwarding)
- macOS or Linux
- Git configured on host (`git config --global user.name` and `user.email`)
- SSH keys available via SSH agent

## Quick Start

### 1. Build the image

```bash
cd ~/Sites/claude-compose-sandbox
docker-compose build
```

### 2. Configure workspace path

**Option A:** Set in shell config (recommended):
```bash
# Add to ~/.zshrc or ~/.bashrc
export WORKSPACE_PATH=/your/workspace/path
alias claude-sandbox='~/Sites/claude-compose-sandbox/claude-sandbox'
```

**Option B:** Use `.env` file:
```bash
cp .env.example .env
# Edit .env and set WORKSPACE_PATH
```

Reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### 3. Run Claude

```bash
claude-sandbox
```

That's it!

## How It Works

### Docker Sandbox Model

Just like `docker sandbox`, this setup maintains **one container per workspace**:

1. **First time**: Creates a new container
2. **Subsequent runs**: Reuses the existing container
3. **State persists**: npm packages, files, changes all persist

### Multiple Terminal Tabs

Open multiple terminal tabs and run `claude-sandbox` in each:

```bash
# Terminal Tab 1
claude-sandbox
> "install express and create a server"

# Terminal Tab 2 (reuses same container)
claude-sandbox
> "create tests for the server"
# Can see express packages installed in Tab 1

# Terminal Tab 3
claude-sandbox
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
claude-sandbox
```

The script automatically:
- Creates container if it doesn't exist
- Reuses existing container if running
- Starts new Claude instance in that container

### Multiple Sessions

```bash
# Terminal 1
claude-sandbox

# Terminal 2 (new tab)
claude-sandbox  # Connects to same container

# Terminal 3 (new tab)
claude-sandbox  # Connects to same container
```

### Stopping/Resetting

To remove the container and start fresh:

```bash
cd ~/Sites/claude-compose-sandbox
docker-compose down
```

Next `claude-sandbox` command will create a new container.

### Viewing Logs

```bash
docker logs -f claude-dev
```

### Manual Container Management

```bash
# Start container manually
docker-compose -f ~/Sites/claude-compose-sandbox/docker-compose.yml \
               -f ~/Sites/claude-compose-sandbox/docker-compose.ssh.yml \
               up -d

# Stop container
docker-compose -f ~/Sites/claude-compose-sandbox/docker-compose.yml down

# Rebuild after changes
docker-compose -f ~/Sites/claude-compose-sandbox/docker-compose.yml build
```

## Configuration

### Workspace Path

Set via environment variable:

```bash
# Option 1: Set for single session
WORKSPACE_PATH=/your/workspace/path claude-sandbox

# Option 2: Set in your shell config (~/.zshrc)
export WORKSPACE_PATH=/your/workspace/path

# Option 3: Create .env file
cp .env.example .env
# Edit WORKSPACE_PATH in .env
```

### SSH Key Selection

Set environment variable to use specific SSH key:

```bash
export SSH_KEY_NAME="[Docker Sandbox] GitHub"
claude-sandbox
```

Or leave unset to use first available key.

### Git Configuration

Git config is automatically read from your `~/.gitconfig`. To verify:

```bash
# Inside container
git config --global --list
```

### Persistent Authentication

Claude authentication is stored in a Docker named volume (`claude-config`) that persists across container restarts:

```bash
# On first run, authenticate via browser
claude-sandbox  # Opens browser for OAuth authentication

# Subsequent runs use the persisted token
claude-sandbox  # No authentication needed

# To reset authentication (force re-login)
docker volume rm claude-compose-sandbox_claude-config
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
3. Optional: Set SSH_KEY_NAME environment variable
   ```bash
   export SSH_KEY_NAME="[Docker Sandbox] GitHub"
   ```

## Troubleshooting

### SSH Signing Not Working

Check SSH agent inside container:

```bash
docker exec claude-dev ssh-add -L
```

Should list your SSH keys. If not:
- Ensure Docker Desktop SSH forwarding is enabled
- For 1Password: enable SSH agent in settings
- Restart Docker Desktop

### Git Config Not Set

Check inside container:

```bash
docker exec claude-dev git config --global --list
```

Should show `user.name` and `user.email`. If not:
- Verify `git config --global user.name` works on host
- Check that `~/.gitconfig` exists on host
- Rebuild: `docker-compose build`

### Container Not Reusing

If each `claude` command creates a new container:

```bash
# Check for existing container
docker ps -a | grep claude-dev

# Remove old containers
docker rm -f claude-dev

# Try again
claude-sandbox
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

## Comparison to docker sandbox

### This Setup (docker-compose)

**Advantages:**
- Full control and transparency over configuration
- Explicit volume mounts and environment variables
- Easy to customize and debug
- Can be version controlled
- Works with standard docker-compose tooling
- Zero-configuration git and SSH setup

**How it's the same:**
- One container per workspace
- Persistent state across sessions
- Multiple terminal support
- Same isolation guarantees

### docker sandbox

**Advantages:**
- Simpler command line interface
- Automatic workspace detection
- Built-in safety features
- Official Anthropic support

**Choose this setup if:**
- You want full control over your environment
- You want zero-configuration git/SSH setup
- You want to understand exactly what's running
- You want to customize the environment

**Choose docker sandbox if:**
- You prefer official tooling
- You want the simplest possible interface
- You don't need custom configuration

## Files

```
claude-compose-sandbox/
├── Dockerfile                   # Based on official Anthropic image
├── docker-compose.yml          # Base configuration
├── docker-compose.ssh.yml      # SSH agent forwarding
├── claude-sandbox              # Wrapper script (mimics docker sandbox)
├── .gitignore
└── README.md
```

## Security

- Container runs as non-root user (`agent`)
- Only workspace directory is mounted
- Home directory mounted read-only (for .gitconfig only)
- SSH keys stay on host, only agent socket forwarded
- sudo limited to `chmod` command only

## Advanced Usage

### Custom Dockerfile Changes

After modifying the Dockerfile:

```bash
docker-compose down  # Remove old container
docker-compose build  # Rebuild image
claude-sandbox  # Start with new image
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
  - ${WORKSPACE_PATH}:${WORKSPACE_PATH}
  - /path/to/other/dir:/mnt/other:ro
```

## Tips

1. **One workspace, one container**: The container name is `claude-dev`, so only one workspace can be active. For multiple workspaces, modify `docker-compose.yml` to use different container names.

2. **Cleanup old containers**: Periodically remove stopped containers:
   ```bash
   docker container prune
   ```

3. **Check disk usage**: Monitor Docker disk usage:
   ```bash
   docker system df
   ```

4. **Fresh start**: To completely reset:
   ```bash
   docker-compose down -v  # Remove volumes too
   docker-compose build --no-cache
   claude-sandbox
   ```
