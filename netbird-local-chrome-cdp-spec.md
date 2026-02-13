# Remote AI-Controlled Local Chrome via NetBird + CDP  
**Architecture + Implementation Guide**

## Objective

Design a development architecture where:

- AI coding tools (Claude CLI, Codex CLI, Playwright agents, etc.) run on a **remote Ubuntu server**
- A **local Windows Chrome** provides the rendering and interactive experience
- The remote tools can **fully control Chrome** via the Chrome DevTools Protocol (CDP)
- All communication occurs securely over **NetBird**
- No remote GUI / VNC / streamed browser
- No localhost exposure to the public internet
- Low latency UX (browser must remain local)

This document contains **complete context and implementation instructions** for another coding LLM to execute.

---

## High-Level Architecture

Remote Ubuntu Server (AI + automation)
        |
        |  NetBird private network
        |
Windows Workstation (Chrome w/ CDP exposed)

The browser stays local.  
The intelligence lives remote.

Communication channel:

Playwright / Puppeteer / AI agent
        ↓
Chrome DevTools Protocol (TCP 9222)
        ↓
NetBird private IP
        ↓
Local Chrome instance

---

## Why This Architecture

The user is a senior DevOps-style developer who:

- Works across multiple machines
- Wants stateless workstations
- Prefers remote compute
- Uses Unix tooling
- Runs AI agents remotely
- Needs deterministic environments
- Rejects remote desktop browser lag

**Key Design Principle:**

> Compute remote. Render local.

---

## Security Model

### Requirements

- No public port exposure  
- No LAN exposure  
- Private overlay only  
- Controlled peer access  

NetBird provides:

- WireGuard-based encrypted mesh
- Private IP addressing
- Peer ACL capability
- NAT traversal

**CDP is effectively root-level browser access**, so strict network scoping matters.

---

## Implementation Steps

### 1) Install NetBird on both machines

#### Linux (remote server)

```bash
curl -fsSL https://pkgs.netbird.io/install.sh | sh
sudo netbird up
```

#### Windows

Install via MSI from NetBird site, then sign in so both nodes join the same NetBird network.

---

### 2) Capture the Windows NetBird IP

On Windows:

```powershell
netbird status
```

Example result:

NetBird IP: 100.73.182.55

Save this as:

- WINDOWS_NETBIRD_IP

---

### 3) Configure NetBird ACLs (mandatory)

Restrict port **TCP 9222** so **only the remote server** can access it.

Policy concept:

- Allow: RemoteServer -> WindowsWorkstation : TCP 9222
- Deny: everyone else

Do not skip this.

---

### 4) Launch a dedicated “automation” Chrome locally (Windows)

Never reuse your personal Chrome profile.

```bat
"C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --remote-debugging-port=9222 ^
  --remote-debugging-address=0.0.0.0 ^
  --user-data-dir="%LOCALAPPDATA%\Chrome-Automation" ^
  --no-first-run ^
  --no-default-browser-check
```

#### Why 0.0.0.0 is acceptable here

Normally this is dangerous. It is only acceptable because:

- The port is reachable only inside NetBird  
- ACL locks access to the single remote peer  

Never expose this to the open internet.

---

### 5) Windows firewall (don’t forget)

Allow inbound TCP 9222 **only** on the NetBird adapter / profile if possible.

---

### 6) Verify CDP accessibility from the remote server

From the remote server:

```bash
curl http://WINDOWS_NETBIRD_IP:9222/json/version
```

Expected JSON includes fields like Browser and webSocketDebuggerUrl.

If this works — the tunnel is complete.

---

## Connect automation tools (remote server)

### Playwright (recommended)

Install:

```bash
npm install playwright
```

Attach via CDP:

```js
import { chromium } from "playwright";

const browser = await chromium.connectOverCDP(
  "http://WINDOWS_NETBIRD_IP:9222"
);

const context =
  browser.contexts()[0] || await browser.newContext();

const page =
  context.pages()[0] || await context.newPage();

await page.goto("https://example.com");
```

---

### Puppeteer

```js
import puppeteer from "puppeteer-core";

const browser = await puppeteer.connect({
  browserURL: "http://WINDOWS_NETBIRD_IP:9222"
});

const page = await browser.newPage();
await page.goto("https://example.com");
```

---

## Provide a stable endpoint for AI tools

On the remote server:

```bash
export CHROME_CDP_URL="http://WINDOWS_NETBIRD_IP:9222"
```

Most agent frameworks/tools call this something like:

- --cdp-url
- --browser-endpoint
- --connect-to-browser
- BROWSER_URL / CHROME_URL

Goal: **connect to existing browser** (your local Chrome) rather than launching a remote one.

---

## Operational best practices

- Keep one persistent Chrome session and reuse contexts to avoid tab explosions.
- Consider separate ports/profiles per purpose:
  - 9222: AI agents
  - 9223: manual debugging
  - 9224: testing sandbox
- Disable sleep on Windows (sleep breaks automation).
- Auto-launch the automation Chrome at login via Task Scheduler if desired.

---

## Troubleshooting

### Can’t reach port 9222 from remote

1) Confirm NetBird connectivity:

```bash
ping WINDOWS_NETBIRD_IP
```

2) Confirm Chrome is listening (Windows):

```powershell
netstat -ano | findstr 9222
```

3) Confirm firewall allows inbound 9222 on the NetBird interface/profile.

4) Confirm NetBird ACL permits RemoteServer -> Windows : 9222.

---

## Strong recommendation (context from the wider conversation)

Treat the remote server as the “dev brain”:

- tmux
- mise or asdf for runtimes
- Docker
- Terraform / kubectl / cloud CLIs
- AI tooling (Claude/Codex/etc.)

Workstations become thin clients. Drift disappears.

---

## Optional: runtime manager note (context)

- mise: modern, fast, good UX; can read .tool-versions
- asdf: very common, stable ecosystem

Either can define per-project versions via a file, making the remote server reproducible.

---

## What NOT to do

- Do not expose CDP publicly
- Do not reuse your personal Chrome profile
- Do not run remote GUI browsers if local snappy UX is the goal
- Do not leave port 9222 open to the whole tailnet without ACLs

---

## Final summary

- Compute: remote Ubuntu server  
- Browser: local Windows Chrome  
- Network: NetBird private overlay  
- Control: Chrome DevTools Protocol (CDP) on TCP 9222  

This is the professional-grade pattern for AI-assisted development with local rendering.
