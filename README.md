# remote-dev

Run AI tools on a remote Ubuntu EC2, controlling your local Chrome browser via CDP over a private NetBird mesh.

## Daily Use

```bash
./start       # launch Chrome + tunnel + code relay
./ssh         # SSH to EC2 as bhudgens (proper systemd session)
./stop        # tear down when done
./status      # dashboard
./sync        # rsync code to EC2
```

On the EC2 as bhudgens:

```bash
code .                              # opens VS Code on your workstation (Remote-SSH)
source scripts/remote/cdp-env.sh    # load CDP env vars for automation
```

## How It Works

```
Windows Workstation                    Remote EC2
  Chrome (localhost:9222)                AI / Playwright
  VS Code                               bhudgens user
        |                                    |
        +---- reverse SSH tunnel (-R) -------+
              9222: CDP (browser control)
              9223: code relay (VS Code)
              over NetBird WireGuard mesh
```

The workstation initiates all connections. The EC2 never connects back. Multiple workstations can each tunnel their own Chrome.

## New Machine Setup

### 1. Prerequisites

- Windows workstation with Chrome and [NetBird](https://netbird.io)
- WSL2 (Ubuntu)
- VS Code with [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension

### 2. Clone and go

```bash
git clone <this-repo> ~/reverts/remote-dev
cd ~/reverts/remote-dev
./start
./ssh
```

That's it. `start` launches Chrome with CDP, creates the reverse tunnels, and starts the code relay. `ssh` connects to the EC2 and drops you into a bhudgens shell with a proper systemd session.

### 3. First time on EC2 as bhudgens

On your first connect, set up benvironment and SSH keys:

```bash
# benvironment auto-installs on first login, then:
keyme    # load SSH keys from Bitwarden (enables VS Code Remote-SSH)
```

After `keyme`, `code .` works from the EC2 and VS Code Remote-SSH can connect.

## Infrastructure Setup (one-time)

Only needed when deploying a new EC2:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in netbird_setup_key and netbird_management_url
tofu init && tofu apply
```

The instance boots with NetBird registered, SSH server enabled, bhudgens user created, and `become-bhudgens.sh` in ubuntu's home.

## Scripts

Top-level scripts are convenience wrappers for the scripts in `scripts/wsl/`.

| Script | Purpose |
|--------|---------|
| `./start` | Launch Chrome + tunnel + code relay (daily driver) |
| `./stop` | Stop code relay + tunnel + Chrome |
| `./ssh` | SSH to EC2, become bhudgens (systemd session) |
| `./sync` | Rsync code and dotfiles to EC2 (per-machine) |
| `./status` | Dashboard: NetBird, Chrome, CDP, tunnel, code relay |

### Remote (EC2)

| Script | Purpose |
|--------|---------|
| `code` | Open file/dir in local VS Code (via relay) |
| `cdp-env.sh` | Source to export CDP env vars |
| `cdp-health.sh` | Verify CDP connectivity through tunnel |

## Security

- Chrome binds to localhost only
- CDP reachable only through SSH tunnel over NetBird
- EC2 security group allows no inbound traffic
- NetBird setup key marked `sensitive` in Terraform
- SSH keys managed via Bitwarden (benvironment's keyme)
- Keys stored on tmpfs, cleaned up when session ends

CDP provides unauthenticated browser access. Security relies on NetBird network isolation and SSH tunnel encryption.
