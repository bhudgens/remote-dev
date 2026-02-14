# remote-dev

Run AI tools on a remote Ubuntu EC2, controlling your local Chrome browser via CDP over a private NetBird mesh.

## Daily Use

```bash
./scripts/wsl/start.sh       # launch Chrome + tunnel + code relay
./scripts/wsl/ssh.sh          # SSH to the EC2
./scripts/wsl/stop.sh         # tear down when done
```

On the EC2 as bhudgens:

```bash
code .                              # opens VS Code on your workstation (Remote-SSH)
source scripts/remote/cdp-env.sh    # load CDP env vars for automation
```

Sync your local code to the EC2:

```bash
./scripts/wsl/sync.sh         # rsync ~/reverts to EC2 (per-machine isolation)
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

## First-Time Setup

### 1. Prerequisites

- Windows workstation with Chrome and [NetBird](https://netbird.io)
- WSL2 (Ubuntu)
- AWS account
- [OpenTofu](https://opentofu.org) installed
- VS Code with [Remote - SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension

### 2. Deploy the EC2

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in netbird_setup_key and netbird_management_url
tofu init && tofu apply
```

The instance boots with NetBird registered, SSH server enabled, and bhudgens user created.

### 3. Verify

Wait ~60s for the EC2 to register, then confirm the peer appears:

```bash
netbird status --detail | grep cloud-development
```

### 4. Setup bhudgens on EC2

SSH to the EC2 and set up the bhudgens user:

```bash
./scripts/wsl/ssh.sh           # SSH as ubuntu
sudo su - bhudgens             # switch to bhudgens
# benvironment auto-installs on first login
keyme                          # load SSH keys from Bitwarden (builds authorized_keys)
```

## Scripts

### WSL2 (workstation)

| Script | Purpose |
|--------|---------|
| `start.sh` | Launch Chrome + tunnel + code relay (daily driver) |
| `stop.sh` | Stop code relay + tunnel + Chrome |
| `ssh.sh` | SSH to the EC2 (auto-discovers IP) |
| `sync.sh` | Rsync code and dotfiles to EC2 (per-machine) |
| `status.sh` | Dashboard: NetBird, Chrome, CDP, tunnel, code relay |

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

CDP provides unauthenticated browser access. Security relies on NetBird network isolation and SSH tunnel encryption.
