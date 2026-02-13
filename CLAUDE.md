# Remote Dev Project

## Architecture

**NetBird mesh + SSH tunnels for CDP access. All tunnels initiated from the CLIENT (workstation).**

- **Multiple Windows workstations** each run Chrome with CDP on localhost:9222
- **NetBird** connects all machines into a WireGuard mesh
- The **client (workstation)** initiates a reverse SSH tunnel to the EC2:
  ```
  ssh -R 9222:localhost:9222 ubuntu@<ec2-netbird-ip>
  ```
  This makes CDP available at localhost:9222 on the EC2 — no SSH server needed on Windows.
- The EC2 never connects back to the workstation. All connections flow client → server.

**Key rules:**
- Never bind CDP to 0.0.0.0 or non-localhost. Chrome stays on localhost:9222.
- All tunnels are initiated FROM the client workstation, never from the EC2.
- No SSH server needed on Windows. No firewall rules for CDP.
- Tunnel scripts live in `scripts/wsl/` (client side), not `scripts/remote/`.

## NetBird SSH

Use `netbird ssh` instead of regular `ssh`. It uses JWT/OIDC auth via the identity provider — no SSH key management needed.

**Key commands:**
- `netbird ssh user@<netbird-ip>` — interactive shell
- `netbird ssh -L 8080:localhost:80 user@<netbird-ip>` — local port forwarding
- `netbird ssh -R 8080:localhost:3000 user@<netbird-ip>` — remote port forwarding

**Server-side flags** (in `netbird up`):
- `--allow-server-ssh` — required to accept SSH connections
- `--enable-ssh-local-port-forwarding` — required for `-L` tunnels
- `--enable-ssh-remote-port-forwarding` — required for `-R` tunnels
- `--enable-ssh-sftp` — enables file transfers

**Important:** Port forwarding only works with `netbird ssh`, NOT with native OpenSSH.
NetBird's embedded SSH server listens on port 22022 (transparent redirect from 22).

## Infrastructure

- **AWS region**: us-east-1 (account: benjamindavid, 070066739317)
- **VPC**: `netbird-vpc` (looked up by Name tag in Terraform)
- **Subnet**: `netbird-public` (looked up by Name tag)
- **SSH key**: `netbird-key`
- **NetBird management**: https://netbird.hudgenda.com:443

## Script Layout

- `scripts/wsl/` — Run from WSL2 on Windows workstation (client)
  - `chrome-launch.sh` — Start Chrome with CDP on localhost
  - `chrome-stop.sh` — Stop automation Chrome
  - `tunnel-start.sh` — Create reverse SSH tunnel to EC2 (forwards local CDP to EC2)
  - `tunnel-stop.sh` — Kill the tunnel
  - `status.sh` — Dashboard showing NetBird, Chrome, CDP, tunnel status
- `scripts/remote/` — Run on EC2 instance (server)
  - `cdp-health.sh` — Verify CDP connectivity (through tunnel on localhost)
  - `cdp-env.sh` — Export env vars for Playwright/automation tools
