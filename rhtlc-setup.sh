#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
#  RHTLC One-Click Setup Script
#  Automates: install → connect → ssh → proxied browser
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SOCKS_PORT=""
CONN_SKU=""
PROXY_BYPASS_DOMAINS="*.redhat.com, *.google.com, *.draw.io"

banner() {
  echo ""
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
  echo -e "${CYAN}${BOLD}   Red Hat Training Lab Companion (RHTLC) Setup${NC}"
  echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════${NC}"
  echo ""
}

info()    { echo -e "${GREEN}[✔]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[✘]${NC} $*"; }
step()    { echo -e "\n${BOLD}── Step $1: $2 ──${NC}"; }

detect_os() {
  case "$(uname -s)" in
    Linux*)  OS="linux" ;;
    Darwin*) OS="mac" ;;
    *)       err "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
}

# ── Step 1: Install RHTLC ──────────────────────────────────
install_rhtlc() {
  step 1 "Installing RHTLC"

  if command -v rhtlc &>/dev/null; then
    local current_version
    current_version=$(rhtlc --version 2>/dev/null || echo 'unknown')
    info "RHTLC is already installed (${current_version})"

    info "Checking for updates..."
    local update_available=false
    if [[ "$OS" == "linux" ]]; then
      sudo dnf copr enable -y tmichett/RHTLC &>/dev/null || true
      if sudo dnf check-update rhtlc 2>/dev/null | grep -q '^rhtlc'; then
        update_available=true
      fi
    elif [[ "$OS" == "mac" ]]; then
      brew update &>/dev/null || true
      if brew outdated --formula 2>/dev/null | grep -q '^rhtlc'; then
        update_available=true
      fi
    fi

    if [[ "$update_available" == "true" ]]; then
      echo ""
      echo -en "${YELLOW}A newer version of RHTLC is available. Do you want to upgrade? (y/n): ${NC}"
      read -r answer
      if [[ "$answer" =~ ^[Yy] ]]; then
        info "Upgrading RHTLC..."
        if [[ "$OS" == "linux" ]]; then
          sudo dnf update -y rhtlc
        elif [[ "$OS" == "mac" ]]; then
          brew upgrade rhtlc
        fi
        info "RHTLC upgraded to $(rhtlc --version 2>/dev/null || echo 'latest')"
      else
        info "Skipping upgrade, continuing with ${current_version}"
      fi
    else
      info "RHTLC is already at the latest version"
    fi
    return
  fi

  if [[ "$OS" == "linux" ]]; then
    info "Detected Linux — installing via DNF COPR..."
    sudo dnf copr enable -y tmichett/RHTLC
    sudo dnf install -y rhtlc
  elif [[ "$OS" == "mac" ]]; then
    if ! command -v brew &>/dev/null; then
      err "Homebrew is not installed. Install it first: https://brew.sh"
      exit 1
    fi
    info "Detected macOS — installing via Homebrew..."
    brew tap RedHatTraining/rhtlc
    brew trust --formula redhattraining/rhtlc/rhtlc
    brew install rhtlc
  fi

  if command -v rhtlc &>/dev/null; then
    info "RHTLC installed successfully ($(rhtlc --version 2>/dev/null || echo 'done'))"
  else
    err "RHTLC installation failed. Please install manually."
    exit 1
  fi
}

# ── Step 2: Check & manage existing connections ─────────────
manage_connections() {
  step 2 "Checking Existing Connections"

  local status_output
  status_output=$(rhtlc status 2>/dev/null) || true

  ACTIVE_SKUS=$(echo "$status_output" | grep -oE 'conn-[0-9]+' | sort -u || true)

  if [[ -z "$ACTIVE_SKUS" ]]; then
    info "No existing connections found"
    return
  fi

  echo ""
  echo -e "${YELLOW}${BOLD}Existing active connections found:${NC}"
  echo "$status_output" | grep -E '^conn-|Port:|Status:' | while read -r line; do
    echo -e "  ${CYAN}${line}${NC}"
  done
  echo ""

  echo -en "${YELLOW}Do you want to remove existing connections? (y/n): ${NC}"
  read -r answer

  if [[ "$answer" =~ ^[Yy] ]]; then
    info "Removing existing connections..."
    for sku in $ACTIVE_SKUS; do
      warn "Disconnecting ${sku}..."
      rhtlc disconnect --sku "$sku" 2>/dev/null || true
    done
    info "All existing connections cleaned up"
  else
    info "Keeping existing connections"
    warn "Your new connection will be assigned the next available port"
  fi
}

# ── Step 3: Connect to classroom environment ────────────────
connect_classroom() {
  manage_connections

  step 3 "Connecting to Classroom Environment"

  echo ""
  echo -e "${YELLOW}${BOLD}ACTION REQUIRED:${NC}"
  echo "  1. Open your browser and go to the classroom URL given by your instructor"
  echo -e "     ${CYAN}(e.g. https://rol.redhat.com/rol/app/classes/<class-id>)${NC}"
  echo -e "  2. Go to the ${BOLD}Labs${NC} tab"
  echo -e "  3. Click ${BOLD}Create Lab${NC} (if not already created)"
  echo -e "  4. Under the RHTLC section, click ${BOLD}COPY RHTLC URL${NC}"
  echo ""

  echo -en "${CYAN}Paste your RHTLC URL here: ${NC}"
  read -r RHTLC_URL

  if [[ -z "$RHTLC_URL" ]]; then
    err "No URL provided. Exiting."
    exit 1
  fi

  info "Connecting to classroom environment..."

  local connect_output
  connect_output=$(rhtlc connect "$RHTLC_URL" 2>&1) || true
  echo "$connect_output"

  SOCKS_PORT=$(echo "$connect_output" | grep -oE 'socks5://127\.0\.0\.1:[0-9]+' | grep -oE '[0-9]+$')
  CONN_SKU=$(echo "$connect_output" | grep -oE 'conn-[0-9]+' | head -1)

  if [[ -z "$SOCKS_PORT" ]]; then
    warn "Could not detect SOCKS port from output, defaulting to 1080"
    SOCKS_PORT="1080"
  fi

  if [[ -z "$CONN_SKU" ]]; then
    warn "Could not detect connection SKU from output"
  fi

  echo ""
  info "Connected successfully!"
  echo -e "  ${BOLD}SOCKS Port:${NC} ${CYAN}${SOCKS_PORT}${NC}"
  echo -e "  ${BOLD}Connection:${NC} ${CYAN}${CONN_SKU:-unknown}${NC}"
}

# ── Step 4: Launch proxied browser ─────────────────────────
launch_browser() {
  step 4 "Launching Proxied Browser for OpenShift Console"

  echo ""
  echo -e "${BOLD}Available browsers:${NC}"
  echo "  1) Firefox"
  echo "  2) Chrome"
  echo ""
  echo -en "${CYAN}Select browser [1-2]: ${NC}"
  read -r browser_choice
  case "$browser_choice" in
    1) _launch_firefox ;;
    2) _launch_chrome ;;
    *) err "Invalid choice. Please select 1-2."; exit 1 ;;
  esac
}

_launch_firefox() {
  local port="${SOCKS_PORT:-1080}"

  if [[ "$OS" == "mac" ]]; then
    local bin="/Applications/Firefox.app/Contents/MacOS/firefox"
  else
    local bin="firefox"
  fi

  if ! command -v "$bin" &>/dev/null && [[ ! -x "$bin" ]]; then
    err "Firefox is not installed. Please install Firefox and re-run."
    exit 1
  fi

  local profile_dir="$HOME/.rhtlc/firefox-profile"
  mkdir -p "$profile_dir"

  if [[ -f "$profile_dir/prefs.js" ]]; then
    sed -i.bak '/network\.proxy\./d' "$profile_dir/prefs.js"
    rm -f "$profile_dir/prefs.js.bak"
  fi

  cat > "$profile_dir/user.js" <<PREFS
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", ${port});
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("network.proxy.no_proxies_on", "${PROXY_BYPASS_DOMAINS}");
PREFS

  info "Starting Firefox with SOCKS proxy on port ${port}..."
  info "Proxy bypass: ${PROXY_BYPASS_DOMAINS}"
  "$bin" -no-remote -profile "$profile_dir" > /dev/null 2>&1 &
  sleep 2
  info "Firefox launched!"
}

_launch_chrome() {
  local port="${SOCKS_PORT:-1080}"

  if [[ "$OS" == "mac" ]]; then
    local bin="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  else
    local bin=""
    for candidate in google-chrome google-chrome-stable chromium-browser chromium; do
      if command -v "$candidate" &>/dev/null; then
        bin="$candidate"
        break
      fi
    done
  fi

  if [[ -z "$bin" ]] || { ! command -v "$bin" &>/dev/null && [[ ! -x "$bin" ]]; }; then
    err "Chrome is not installed. Please install Chrome and re-run."
    exit 1
  fi

  local bypass_list
  bypass_list=$(echo "$PROXY_BYPASS_DOMAINS" | tr ',' ';' | tr -d ' ')

  local user_data_dir="$HOME/.rhtlc/chrome-profile"
  mkdir -p "$user_data_dir"

  info "Starting Chrome with SOCKS proxy on port ${port}..."
  info "Proxy bypass: ${PROXY_BYPASS_DOMAINS}"
  "$bin" \
    --proxy-server="socks5://127.0.0.1:${port}" \
    --proxy-bypass-list="$bypass_list" \
    --user-data-dir="$user_data_dir" \
    > /dev/null 2>&1 &
  sleep 2
  info "Chrome launched!"
}

# ── Step 5: SSH into workstation ────────────────────────────
ssh_workstation() {
  step 5 "SSH into Workstation"

  local ssh_target="student@workstation"
  if [[ -n "${CONN_SKU:-}" ]]; then
    ssh_target="student@workstation-${CONN_SKU}"
  fi

  echo ""
  echo -e "${GREEN}${BOLD}OpenShift Console Access:${NC}"
  echo -e "  URL:      ${CYAN}https://console-openshift-console.apps.ocp4.example.com${NC}"
  echo -e "  Username: ${BOLD}admin${NC}"
  echo -e "  Password: ${BOLD}redhatocp${NC}"
  echo -e "  ${YELLOW}(If you see a warning, click Advanced → Proceed)${NC}"
  echo ""
  echo -e "${GREEN}${BOLD}Connecting to workstation via SSH...${NC}"
  echo -e "  SSH Command: ${BOLD}rhtlc ssh ${ssh_target}${NC}"
  echo -e "  Password:    ${BOLD}student${NC}"
  echo ""

  rhtlc ssh "$ssh_target"
}

# ── Main ────────────────────────────────────────────────────
main() {
  banner
  detect_os

  case "${1:-full}" in
    install)
      install_rhtlc
      ;;
    connect)
      connect_classroom
      ;;
    browser)
      launch_browser
      ;;
    ssh)
      ssh_workstation
      ;;
    full)
      install_rhtlc
      connect_classroom
      launch_browser
      ssh_workstation
      ;;
    daily)
      step 1 "Daily Lab Access"
      info "Starting tunnel and browser..."
      manage_connections
      launch_browser
      ssh_workstation
      ;;
    cleanup)
      manage_connections
      ;;
    *)
      echo "Usage: $0 {full|daily|install|connect|cleanup|browser|ssh}"
      echo ""
      echo "  full      — First-time setup: install + connect + browser + ssh"
      echo "  daily     — Daily use: manage connections + browser + ssh"
      echo "  install   — Only install RHTLC"
      echo "  connect   — Only connect to classroom (paste URL)"
      echo "  cleanup   — Manage existing connections"
      echo "  browser   — Only launch proxied browser (Firefox/Chrome)"
      echo "  ssh       — Only SSH into workstation"
      exit 1
      ;;
  esac

  echo ""
  echo -e "${GREEN}${BOLD}All done! Happy learning! 🎓${NC}"
  echo ""
}

main "$@"
