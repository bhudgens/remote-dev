# Remote Dev Project

## Architecture

**NetBird mesh + SSH tunnels for CDP access and VS Code relay. All tunnels initiated from the CLIENT (workstation).**

- **Multiple Windows workstations** each run Chrome with CDP on localhost:9222
- **NetBird** connects all machines into a WireGuard mesh
- The **client (workstation)** initiates a reverse SSH tunnel to the EC2:
  ```
  ssh -R 9222:localhost:9222 -R 9223:localhost:9223 ubuntu@<ec2-netbird-ip>
  ```
  - Port 9222: Chrome CDP (browser automation)
  - Port 9223: VS Code relay (`code .` on EC2 opens VS Code locally)
- The EC2 never connects back to the workstation. All connections flow client -> server.

**Key rules:**
- Never bind CDP to 0.0.0.0 or non-localhost. Chrome stays on localhost:9222.
- All tunnels are initiated FROM the client workstation, never from the EC2.
- No SSH server needed on Windows. No firewall rules for CDP.
- Tunnel scripts live in `scripts/wsl/` (client side), not `scripts/remote/`.

## Users and SSH

- **ubuntu**: SSH entry point (AWS key pair `remote-dev-key`). All scripts SSH as ubuntu.
- **bhudgens**: Working user. Created in user-data with passwordless sudo. User runs `sudo su - bhudgens` after SSH-ing as ubuntu.
- **VS Code Remote-SSH** connects directly as bhudgens. SSH authorized_keys for bhudgens are built by benvironment's `keyme` function (pulls keys from Bitwarden, generates `authorized_keys` from `.pub` files).
- **benvironment** (`~/reverts/benvironment`): User's personal environment automation. Self-installs tooling, zsh, oh-my-zsh, dotfiles. The `keyme` function manages SSH keys dynamically from Bitwarden — it purges `~/.ssh` and replaces it with a symlink to a temp dir containing keys loaded from Bitwarden.

## VS Code Integration

The `code .` command on the EC2 triggers VS Code on the local workstation via a reverse tunnel relay:

```
EC2: code /some/path
  -> nc sends path to localhost:9223
  -> reverse SSH tunnel forwards to WSL2:9223
  -> code-relay.sh receives path
  -> runs: code --remote ssh-remote+bhudgens@<ip> /some/path
  -> Windows VS Code opens in Remote-SSH mode
```

**Prerequisites:** VS Code with the "Remote - SSH" extension installed on Windows.

**Setup:** Run `keyme` on the EC2 as bhudgens to generate `~/.ssh/authorized_keys` (required for VS Code Remote-SSH to authenticate).

## Per-Machine Sync

Each workstation syncs to its own directory on the EC2 to avoid collisions:

```
/home/bhudgens/machines/<hostname>/
  reverts/    <- code from ~/reverts/
  dotfiles/   <- config files (.claude, etc.)
```

`sync.sh` handles this with auto-discovery of the EC2 IP and per-machine directory isolation. Dotfiles managed by benvironment (.gitconfig, .ssh/*, .zshrc) are NOT synced — benvironment handles those.

## Infrastructure

- **AWS region**: us-east-1 (account: benjamindavid, 070066739317)
- **VPC**: `cloud-development-vpc` (looked up by Name tag in Terraform)
- **Subnet**: `cloud-development-public` (looked up by Name tag)
- **SSH key**: `remote-dev-key` (imported from local ~/.ssh/id_rsa)
- **NetBird management**: https://netbird.hudgenda.com:443
- **Instance type**: t3.medium (Ubuntu 24.04 LTS)
- **IaC**: OpenTofu (`tofu`, not `terraform`)

## NetBird SSH

NetBird's embedded SSH server runs on port 22022 with transparent redirect from port 22.

**Server-side flags** (in `netbird up` user-data):
- `--allow-server-ssh` — accept SSH connections
- `--enable-ssh-local-port-forwarding` — `-L` tunnels
- `--enable-ssh-remote-port-forwarding` — `-R` tunnels
- `--enable-ssh-sftp` — file transfers

In practice, regular SSH (not `netbird ssh`) works for tunnels and VS Code over the NetBird mesh.

**Limitation:** NetBird's SSH server does NOT support multiple `-R` ports on a single connection. Each reverse tunnel port needs its own SSH connection. This is why the CDP tunnel (9222) and code relay tunnel (9223) use separate SSH processes.

## Script Layout

- `scripts/config.env` — Shared configuration (ports, paths, peer name)
- `scripts/lib.sh` — Shared functions (logging, NetBird discovery, CDP health)
- `scripts/wsl/` — Run from WSL2 on Windows workstation (client)
  - `start.sh` — Daily driver: Chrome + tunnel + code relay
  - `stop.sh` — Tear down everything
  - `ssh.sh` — SSH to EC2 (auto-discovers IP)
  - `sync.sh` — Rsync code and dotfiles to EC2 (per-machine isolation)
  - `status.sh` — Dashboard: NetBird, Chrome, CDP, tunnel, code relay
  - `chrome-launch.sh` / `chrome-stop.sh` — Chrome lifecycle
  - `tunnel-start.sh` / `tunnel-stop.sh` — Reverse SSH tunnel lifecycle
  - `code-relay.sh` — Background listener for VS Code relay
- `scripts/remote/` — Run on EC2 instance (server)
  - `cdp-health.sh` — Verify CDP connectivity (through tunnel on localhost)
  - `cdp-env.sh` — Export env vars for Playwright/automation tools
  - `code` — VS Code relay wrapper (sends path back through tunnel)

## Daily Workflow

```bash
# On WSL2 (workstation):
./scripts/wsl/start.sh        # launch Chrome + tunnel + code relay
./scripts/wsl/ssh.sh           # SSH to the EC2
./scripts/wsl/sync.sh          # sync code to EC2
./scripts/wsl/stop.sh          # tear down when done

# On EC2 (as bhudgens):
code .                         # open current dir in local VS Code
source scripts/remote/cdp-env.sh  # load CDP env vars for automation
```

## Known Issues

- **Stale NetBird peers**: When EC2 is rebuilt, the old peer stays in NetBird management. Delete stale peers from the NetBird dashboard and rename the new peer to `cloud-development`.
- **user_data_replace_on_change**: Updating user-data in Terraform destroys and recreates the instance. A new NetBird setup key is needed.
- **keyme required for VS Code**: VS Code Remote-SSH won't work until `keyme` is run on the EC2 as bhudgens (builds authorized_keys).
- **NetBird multi-port limitation**: NetBird SSH doesn't support multiple `-R` ports per connection. Each port needs a separate SSH process.
