#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
#  RHTLC One-Click Setup Script
#  Automates: install → connect → ssh → proxied Firefox
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SOCKS_PORT=""
CONN_SKU=""

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
    info "RHTLC is already installed ($(rhtlc --version 2>/dev/null || echo 'version unknown'))"
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

  ACTIVE_SKUS=$(echo "$status_output" | grep -oE 'conn-[0-9]+' | sort -u)

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
  echo "  1. Open your browser and go to:"
  echo -e "     ${CYAN}https://rol.redhat.com/rol/app/classes/bbd9ce42-1bb5-403b-a3a0-3f8daf6e09a6${NC}"
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

# ── Step 4: Launch proxied Firefox ──────────────────────────
launch_firefox() {
  step 4 "Launching Proxied Firefox for OpenShift Console"

  if [[ "$OS" == "mac" ]]; then
    FIREFOX_BIN="/Applications/Firefox.app/Contents/MacOS/firefox"
  else
    FIREFOX_BIN="firefox"
  fi

  if ! command -v "$FIREFOX_BIN" &>/dev/null && [[ ! -x "$FIREFOX_BIN" ]]; then
    err "Firefox is not installed. Please install Firefox and re-run this script."
    exit 1
  fi

  local port="${SOCKS_PORT:-1080}"

  PROFILE_NAME="rhtlc-proxy"
  PROFILE_DIR="$HOME/.rhtlc/firefox-profile"

  if [[ ! -d "$PROFILE_DIR" ]]; then
    info "Creating Firefox profile directory..."
    mkdir -p "$PROFILE_DIR"
    info "Profile directory created at $PROFILE_DIR"
  else
    info "Firefox profile '${PROFILE_NAME}' already exists"
  fi

  cat > "$PROFILE_DIR/user.js" <<PREFS
user_pref("network.proxy.type", 1);
user_pref("network.proxy.socks", "127.0.0.1");
user_pref("network.proxy.socks_port", ${port});
user_pref("network.proxy.socks_version", 5);
user_pref("network.proxy.socks_remote_dns", true);
PREFS

  info "Starting Firefox with SOCKS proxy on port ${port}..."
  "$FIREFOX_BIN" -no-remote -profile "$PROFILE_DIR" > /dev/null 2>&1 &

  sleep 2
  info "Firefox launched!"
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
    firefox)
      launch_firefox
      ;;
    ssh)
      ssh_workstation
      ;;
    full)
      install_rhtlc
      connect_classroom
      launch_firefox
      ssh_workstation
      ;;
    daily)
      step 1 "Daily Lab Access"
      info "Starting tunnel and Firefox..."
      manage_connections
      launch_firefox
      ssh_workstation
      ;;
    cleanup)
      manage_connections
      ;;
    *)
      echo "Usage: $0 {full|daily|install|connect|cleanup|firefox|ssh}"
      echo ""
      echo "  full    — First-time setup: install + connect + firefox + ssh"
      echo "  daily   — Daily use: manage connections + firefox + ssh"
      echo "  install — Only install RHTLC"
      echo "  connect — Only connect to classroom (paste URL)"
      echo "  cleanup — Manage existing connections"
      echo "  firefox — Only launch proxied Firefox"
      echo "  ssh     — Only SSH into workstation"
      exit 1
      ;;
  esac

  echo ""
  echo -e "${GREEN}${BOLD}All done! Happy learning! 🎓${NC}"
  echo ""
}

main "$@"
