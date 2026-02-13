# remote-dev

Run AI tools on a remote Ubuntu EC2 instance, controlling a local Windows Chrome browser via CDP over a private NetBird mesh.

```
Windows Workstation (Chrome on localhost:9222)
        |
        |  reverse SSH tunnel (-R 9222)
        |
        |  NetBird (WireGuard mesh)
        |
Remote EC2 (AI + automation sees CDP at localhost:9222)
```

All tunnels are initiated from the workstation. The EC2 never connects back.

## Prerequisites

- Windows workstation with Chrome and NetBird
- WSL2 (Ubuntu) on the workstation
- Self-hosted NetBird management server
- AWS account with OpenTofu installed locally

## Setup

### 1. Deploy the EC2

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in netbird_setup_key and netbird_management_url
tofu init && tofu apply
```

The instance boots with NetBird registered and SSH server enabled.

### 2. Launch Chrome (WSL2)

```bash
./scripts/wsl/chrome-launch.sh
```

Opens Chrome with CDP on localhost:9222 using a separate automation profile.

### 3. Start the tunnel (WSL2)

```bash
./scripts/wsl/tunnel-start.sh
```

Creates a reverse SSH tunnel so the EC2 can reach your Chrome at its own localhost:9222.

### 4. Use from the EC2

```bash
source scripts/remote/cdp-env.sh
```

Exports `CHROME_CDP_URL` and `BROWSER_WS_ENDPOINT` for Playwright, Puppeteer, or any automation tool.

### 5. Check status

```bash
# From WSL2 — full dashboard
./scripts/wsl/status.sh

# From EC2 — CDP health check
./scripts/remote/cdp-health.sh
```

### 6. Tear down

```bash
./scripts/wsl/tunnel-stop.sh    # stop tunnel
./scripts/wsl/chrome-stop.sh    # stop Chrome
```

## Scripts

### WSL2 (workstation)

| Script | Purpose |
|--------|---------|
| `chrome-launch.sh` | Start Chrome with CDP on localhost |
| `chrome-stop.sh` | Stop automation Chrome |
| `tunnel-start.sh [ec2_ip]` | Reverse tunnel to EC2 (auto-discovers cloud-development peer) |
| `tunnel-stop.sh` | Stop the tunnel |
| `status.sh` | Dashboard: NetBird, Chrome, CDP, tunnel |

### Remote (EC2)

| Script | Purpose |
|--------|---------|
| `cdp-env.sh` | Source to export CDP env vars |
| `cdp-health.sh` | Verify CDP connectivity through tunnel |

## Security

- Chrome binds to localhost only
- CDP is only reachable through the SSH tunnel over NetBird
- EC2 security group allows no inbound traffic
- NetBird setup key is marked `sensitive` in Terraform

CDP provides unauthenticated browser access. Security relies on NetBird network isolation and SSH tunnel encryption.
