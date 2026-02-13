# remote-dev

Remote AI development platform. AI tools run on a remote Ubuntu EC2 instance and control a local Windows Chrome browser via the Chrome DevTools Protocol (CDP) over a private NetBird network.

```
Remote Ubuntu EC2 (AI + automation)
        |
        |  NetBird (WireGuard mesh)
        |
Windows Workstation (Chrome w/ CDP)
```

Compute remote. Render local.

## Prerequisites

- Windows workstation with Chrome and NetBird installed
- WSL2 (Ubuntu) on the workstation
- Self-hosted NetBird management server with a setup key
- AWS account with Terraform installed locally
- [Granted](https://granted.dev) for AWS SSO credential management

## Quick Start

### 1. Provision the EC2 instance

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Fill in netbird_setup_key and netbird_management_url
terraform init && terraform apply
```

The instance boots with NetBird auto-registered to your mesh.

### 2. Set up Windows Firewall (one-time, from WSL2)

Run from an elevated (Administrator) WSL2 terminal:

```bash
./scripts/wsl/firewall-setup.sh
```

Creates an inbound allow rule for TCP 9222 scoped to the NetBird interface only.

### 3. Launch Chrome (from WSL2)

```bash
./scripts/wsl/chrome-launch.sh
```

Discovers your NetBird IP and launches Chrome bound to it — not `0.0.0.0`. A separate automation profile is used so your normal browsing is unaffected.

### 4. Connect from the remote server

SSH to the EC2 instance via NetBird, then:

```bash
source scripts/remote/cdp-env.sh <WINDOWS_NETBIRD_IP>
```

This exports `CHROME_CDP_URL` and `BROWSER_WS_ENDPOINT` for use by Playwright, Puppeteer, or any AI agent framework.

## Scripts

### WSL2 (run from your workstation)

| Script | Purpose |
|--------|---------|
| `scripts/wsl/chrome-launch.sh [port]` | Launch Chrome with CDP bound to NetBird IP |
| `scripts/wsl/chrome-stop.sh` | Stop the automation Chrome instance |
| `scripts/wsl/firewall-setup.sh [port]` | One-time Windows Firewall rule setup |
| `scripts/wsl/status.sh [port]` | Dashboard: NetBird, Chrome, and CDP status |

### Remote (run on the EC2 instance)

| Script | Purpose |
|--------|---------|
| `scripts/remote/cdp-env.sh <ip>` | Source to export CDP env vars for AI tools |
| `scripts/remote/cdp-health.sh <ip> [port]` | Layered health check (network, HTTP, WebSocket) |

### Shared

| File | Purpose |
|------|---------|
| `scripts/config.env` | Chrome path, CDP port, NetBird executable path |
| `scripts/lib.sh` | Shared functions (NetBird IP discovery, CDP checks) |

## Security

- Chrome binds to the NetBird interface IP only (never `0.0.0.0`)
- CDP port is accessible only over the NetBird WireGuard mesh
- Windows Firewall rule is scoped to the NetBird network adapter
- EC2 security group allows no inbound traffic by default
- NetBird setup key is marked `sensitive` in Terraform

CDP provides unauthenticated root-level browser access. The security model relies entirely on NetBird network isolation. Do not expose CDP to any other network.

## Terraform Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `instance_type` | `t3.medium` | EC2 instance type |
| `netbird_setup_key` | (required) | NetBird peer registration key |
| `netbird_management_url` | (required) | Self-hosted NetBird management URL |
| `key_name` | `null` | SSH key pair for emergency access |
| `allowed_ssh_cidr` | `[]` | CIDRs allowed for inbound SSH |
| `root_volume_size` | `30` | Root EBS volume size in GB |
| `tags` | `{ Project = "remote-dev" }` | Resource tags |
