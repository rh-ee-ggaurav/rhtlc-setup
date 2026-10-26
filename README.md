# RHTLC Setup Script

Automates the Red Hat Training Lab Companion (RHTLC) setup — installs RHTLC, connects to your classroom lab, opens the OpenShift console in a proxied Firefox, and SSHes into the workstation. All in one command.

## Prerequisites

- **Linux (Fedora/RHEL):** `dnf` package manager
- **macOS:** [Homebrew](https://brew.sh)
- **Firefox** installed on your system

## First-Time Setup

1. Download the script:
   ```bash
   curl -O https://raw.githubusercontent.com/<your-repo>/main/rhtlc-setup.sh
   chmod +x rhtlc-setup.sh
   ```

2. Run the setup:
   ```bash
   ./rhtlc-setup.sh
   ```

3. When prompted, go to the [Red Hat Online Learning Portal](https://rol.redhat.com), open the **Labs** tab, click **Create Lab**, then **COPY RHTLC URL** and paste it into the terminal.

4. A Firefox window will open with proxy configured. Navigate to:
   ```
   https://console-openshift-console.apps.ocp4.example.com
   ```
   - Username: `admin`
   - Password: `redhatocp`
   - If you see a security warning, click **Advanced** then **Proceed**

5. The script will SSH you into the workstation:
   - Password: `student`

## Daily Use

After the first-time setup, just run:

```bash
./rhtlc-setup.sh daily
```

This cleans up old connections, launches Firefox with the proxy, and SSHes into the workstation.

## Other Commands

| Command | What it does |
|---------|-------------|
| `./rhtlc-setup.sh full` | Full first-time setup (default) |
| `./rhtlc-setup.sh daily` | Daily reconnect |
| `./rhtlc-setup.sh install` | Only install RHTLC |
| `./rhtlc-setup.sh connect` | Only connect to classroom |
| `./rhtlc-setup.sh cleanup` | Only manage existing connections |
| `./rhtlc-setup.sh firefox` | Only launch proxied Firefox |
| `./rhtlc-setup.sh ssh` | Only SSH into workstation |
