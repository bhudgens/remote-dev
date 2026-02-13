# remote-dev

Run AI tools on a remote Ubuntu EC2, controlling your local Chrome browser via CDP over a private NetBird mesh.

## Daily Use

```bash
# Start everything (Chrome + tunnel)
./scripts/wsl/start.sh

# SSH to the EC2 and work
ssh ubuntu@100.74.235.42

# When done
./scripts/wsl/stop.sh
```

That's it. `start.sh` launches Chrome, creates a reverse SSH tunnel to the EC2, and shows status. The EC2 sees Chrome CDP at its own `localhost:9222`.

On the EC2, load CDP env vars for automation tools:

```bash
source scripts/remote/cdp-env.sh
# Now CHROME_CDP_URL and BROWSER_WS_ENDPOINT are set
```

## How It Works

```
Windows Workstation                    Remote EC2
  Chrome (localhost:9222)                AI / Playwright
        |                                    |
        +---- reverse SSH tunnel (-R) -------+
              over NetBird WireGuard mesh
```

The workstation initiates all connections. The EC2 never connects back. Multiple workstations can each tunnel their own Chrome.

## First-Time Setup

### 1. Prerequisites

- Windows workstation with Chrome and [NetBird](https://netbird.io)
- WSL2 (Ubuntu)
- AWS account
- [OpenTofu](https://opentofu.org) installed

### 2. Deploy the EC2

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in netbird_setup_key and netbird_management_url
tofu init && tofu apply
```

The instance boots with NetBird registered and its SSH server enabled.

### 3. Verify

Wait ~60s for the EC2 to register, then confirm the peer appears:

```bash
netbird status --detail | grep cloud-development
```

## Scripts

### WSL2 (workstation)

| Script | Purpose |
|--------|---------|
| `start.sh` | Launch Chrome + tunnel (daily driver) |
| `stop.sh` | Stop tunnel + Chrome |
| `status.sh` | Dashboard: NetBird, Chrome, CDP, tunnel |
| `chrome-launch.sh` | Start Chrome with CDP on localhost |
| `chrome-stop.sh` | Stop automation Chrome |
| `tunnel-start.sh [ip]` | Reverse tunnel to EC2 |
| `tunnel-stop.sh` | Stop the tunnel |

### Remote (EC2)

| Script | Purpose |
|--------|---------|
| `cdp-env.sh` | Source to export CDP env vars |
| `cdp-health.sh` | Verify CDP connectivity through tunnel |

## Security

- Chrome binds to localhost only
- CDP reachable only through SSH tunnel over NetBird
- EC2 security group allows no inbound traffic
- NetBird setup key marked `sensitive` in Terraform

CDP provides unauthenticated browser access. Security relies on NetBird network isolation and SSH tunnel encryption.
