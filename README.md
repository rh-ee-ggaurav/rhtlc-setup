# RHTLC Setup Script

Automates the Red Hat Training Lab Companion (RHTLC) setup — installs RHTLC (and checks for updates), connects to your classroom lab, opens the OpenShift console in a proxied browser (Firefox or Chrome), and SSHes into the workstation. All in one command.

## Prerequisites

- **Linux (Fedora/RHEL):** `dnf` package manager
- **macOS:** [Homebrew](https://brew.sh)
- **Firefox** or **Chrome** installed on your system

## First-Time Setup

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/rh-ee-ggaurav/rhtlc-setup/main/rhtlc-setup.sh
   chmod +x rhtlc-setup.sh
   ```

2. Run the setup:
   ```bash
   ./rhtlc-setup.sh
   ```

3. When prompted, go to the classroom URL given by your instructor (e.g. `https://rol.redhat.com/rol/app/classes/<class-id>`), open the **Labs** tab, click **Create Lab**, then **COPY RHTLC URL** and paste it into the terminal.

4. Select your preferred browser (Firefox or Chrome). A new browser window will open with the SOCKS proxy configured and the following domains excluded from the proxy:
   - `*.redhat.com` 
   - `*.google.com`
   - `*.draw.io`

5. Navigate to the OpenShift console:
   ```
   https://console-openshift-console.apps.ocp4.example.com
   ```
   - Username: `admin`
   - Password: `redhatocp`
   - If you see a security warning, click **Advanced** then **Proceed**

6. The script will SSH you into the workstation:
   - Password: `student`

## Daily Use

After the first-time setup, just run:

```bash
./rhtlc-setup.sh daily
```

This cleans up old connections, launches the proxied browser, and SSHes into the workstation.

## Other Commands

| Command | What it does |
|---------|-------------|
| `./rhtlc-setup.sh full` | Full first-time setup (default) |
| `./rhtlc-setup.sh daily` | Daily reconnect |
| `./rhtlc-setup.sh install` | Only install/upgrade RHTLC |
| `./rhtlc-setup.sh connect` | Only connect to classroom |
| `./rhtlc-setup.sh cleanup` | Only manage existing connections |
| `./rhtlc-setup.sh browser` | Only launch proxied browser (Firefox/Chrome) |
| `./rhtlc-setup.sh ssh` | Only SSH into workstation |

## Notes

- The browser opens as a **separate instance** with its own profile (`~/.rhtlc/firefox-profile` or `~/.rhtlc/chrome-profile`), so it won't affect your regular browser sessions.
- If RHTLC is already installed, the script checks for updates and prompts you to upgrade if a newer version is available.
