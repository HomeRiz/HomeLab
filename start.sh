#!/usr/bin/env bash
#
# HomeLab Installer
# https://github.com/HomeRiz/HomeLab
#
# One-liner install:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/HomeRiz/HomeLab/main/start.sh)"

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/HomeRiz/HomeLab"
DEFAULT_DIR="${HOME}/homelab"

# ─── Colors (only when connected to a terminal) ───────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[FAIL]${NC}  $*" >&2; exit 1; }
hr()   { echo -e "${BOLD}$(printf '%.0s─' $(seq 1 60))${NC}"; }

ask_yn() {
  local prompt="$1" default="${2:-y}" yn hint
  [[ "$default" == "y" ]] && hint="Y/n" || hint="y/N"
  while true; do
    printf "${YELLOW}?${NC} %s [%s]: " "$prompt" "$hint"
    read -r yn < /dev/tty
    yn="${yn:-$default}"
    case "${yn,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *)     echo "  Please enter y or n." ;;
    esac
  done
}

gen_secret() {
  openssl rand -hex 32 2>/dev/null \
    || python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null \
    || head -c 32 /dev/urandom | xxd -p 2>/dev/null \
    || date +%s%N | sha256sum | head -c 64
}

# ─── Banner ───────────────────────────────────────────────────────────────────
banner() {
  clear 2>/dev/null || true
  echo -e "${CYAN}${BOLD}"
  cat << 'BANNER'
  _   _                      _          _
 | | | | ___  _ __ ___   ___| |    __ _| |__
 | |_| |/ _ \| '_ ` _ \ / _ \ |   / _` | '_ \
 |  _  | (_) | | | | | |  __/ |__| (_| | |_) |
 |_| |_|\___/|_| |_| |_|\___|_____\__,_|_.__/
BANNER
  echo -e "${NC}"
  echo -e "  ${BOLD}Self-hosted HomeLab Installer${NC}  —  ${CYAN}${REPO_URL}${NC}"
  echo
}

# ─── Prerequisites ────────────────────────────────────────────────────────────
check_prereqs() {
  hr
  info "Checking prerequisites..."
  [[ "$(uname -s)" == "Linux" ]] || die "This script only supports Linux."
  command -v curl &>/dev/null      || die "curl is required. Install it first (e.g. apt install curl)."
  ok "Linux detected, curl available."
  echo
}

# ─── Step 1: Docker ───────────────────────────────────────────────────────────
step_docker() {
  hr
  echo -e "${BOLD}STEP 1 / 5 — Docker${NC}"
  hr

  if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
    ok "Docker $(docker --version | head -1) already installed — skipping."
    echo
    return 0
  fi

  info "Docker not found. Fetching install script for dry-run..."
  local script="/tmp/get-docker-$$.sh"
  trap 'rm -f "$script"' EXIT
  curl -fsSL https://get.docker.com -o "$script" \
    || die "Failed to download Docker install script."

  echo
  info "Running install dry-run (no changes will be made yet)..."
  hr
  local dry_exit=0
  sudo sh "$script" --dry-run || dry_exit=$?
  hr
  echo

  if [[ $dry_exit -ne 0 ]]; then
    warn "Dry-run exited with code $dry_exit. Review the output above."
    ask_yn "Proceed with Docker installation anyway?" n \
      || die "Aborted by user."
  else
    ok "Dry-run completed without errors."
    ask_yn "Install Docker now?" y \
      || die "Aborted by user."
  fi

  info "Installing Docker..."
  curl -fsSL https://get.docker.com/ | sh \
    || die "Docker installation failed."
  ok "Docker installed."

  rm -f "$script"; trap - EXIT

  # Add user to docker group so non-root use works after re-login
  if ! id -nG "$USER" 2>/dev/null | grep -qw docker; then
    info "Adding $USER to the docker group..."
    sudo usermod -aG docker "$USER"
    warn "Group change takes effect after your next login."
    warn "This script will use 'sudo docker' in the meantime."
  fi

  info "Verifying Docker with hello-world..."
  if sudo docker run --rm hello-world &>/dev/null; then
    ok "Docker is working correctly."
  else
    warn "hello-world test failed — proceeding anyway."
  fi
  echo
}

# ─── Step 2: Install Directory ────────────────────────────────────────────────
INSTALL_DIR=""

step_dir() {
  hr
  echo -e "${BOLD}STEP 2 / 5 — Installation Directory${NC}"
  hr
  printf "${YELLOW}?${NC} Install path [%s]: " "$DEFAULT_DIR"
  read -r INSTALL_DIR < /dev/tty
  INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"

  if [[ -d "$INSTALL_DIR" ]] && [[ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]]; then
    warn "Directory $INSTALL_DIR already exists and is not empty."
    ask_yn "Continue? (files may be overwritten)" n || die "Aborted by user."
  fi

  ok "Install path: $INSTALL_DIR"
  echo
}

# ─── Step 3: Application Selection ───────────────────────────────────────────
SELECTED_APPS=()

# Maps a user-facing app key → compose service name(s) in the root compose.yaml
# (cloudflared and pangolin use their own compose files — handled separately)
get_services() {
  case "$1" in
    crowdsec)               echo "crowdsec crowdsec-bouncer" ;;
    crowdsec-console)       echo "crowdsec-console" ;;
    openappsec)             echo "appsec-agent appsec-nginx" ;;
    authelia)               echo "authelia" ;;
    geoip-blocker)          echo "geoip-blocker" ;;
    anubis)                 echo "anubis" ;;
    vaultwarden)            echo "vaultwarden" ;;
    bitwarden)              echo "bitwarden" ;;
    homepage)               echo "homepage" ;;
    dashy)                  echo "dashy" ;;
    autoheal)               echo "autoheal" ;;
    watchtower)             echo "watchtower" ;;
    diun)                   echo "diun" ;;
    adguardhome)            echo "unbound adguardhome adguardhome-sync" ;;
    netbird)                echo "netbird-management netbird-signal" ;;
    watch-your-lan)         echo "watch-your-lan" ;;
    uptime-kuma)            echo "uptime-kuma" ;;
    dozzle)                 echo "dozzle" ;;
    glances)                echo "glances" ;;
    speedtest-tracker)      echo "speedtest-tracker" ;;
    linux-update-dashboard) echo "linux-update-dashboard" ;;
    monocker)               echo "monocker" ;;
    portracker)             echo "portracker" ;;
    paperless-ngx)          echo "paperless-ngx" ;;
    hoarder)                echo "hoarder" ;;
    homebox)                echo "homebox" ;;
    firefly-iii)            echo "firefly-iii" ;;
    vikunja)                echo "vikunja" ;;
    stirling-pdf)           echo "stirling-pdf" ;;
    apprise)                echo "apprise" ;;
    stalwart-mail)          echo "stalwart-mail" ;;
    # cloudflared and pangolin are handled via their own compose files
    cloudflared|pangolin)   echo "" ;;
    *)                      echo "$1" ;;
  esac
}

_select_whiptail() {
  local H W L
  H=$(( $(tput lines 2>/dev/null || echo 40) - 2 ))
  W=$(( $(tput cols  2>/dev/null || echo 100) - 6 ))
  L=$(( H - 10 ))
  [[ $H -lt 24 ]] && H=40
  [[ $W -lt 72 ]] && W=90
  [[ $L -lt 12 ]] && L=28

  local raw
  raw=$(whiptail \
    --title " HomeLab — Select Applications " \
    --checklist \
"SPACE = toggle    ARROW KEYS = navigate    ENTER = confirm
Checked items are recommended. Core infrastructure is always installed:
  Caddy (reverse proxy), PostgreSQL, Redis, Docker-Socket-Proxy
" \
    "$H" "$W" "$L" \
    \
    "crowdsec"               "[Security]    CrowdSec + Bouncer — crowd-sourced IPS"                 ON  \
    "crowdsec-console"       "[Security]    CrowdSec Console — threat monitoring dashboard"          ON  \
    "openappsec"             "[Security]    OpenAppSec — Web Application Firewall (WAF)"             ON  \
    "authelia"               "[Security]    Authelia — SSO & Two-Factor Authentication gateway"      ON  \
    "geoip-blocker"          "[Security]    GeoIP Blocker — country-based IP blocking"               ON  \
    "anubis"                 "[Security]    Anubis — PoW bot protection & DDoS mitigation"           ON  \
    "vaultwarden"            "[Passwords]   Vaultwarden — lightweight Bitwarden-compatible server"   ON  \
    "bitwarden"              "[Passwords]   Bitwarden — official server (more resource-intensive)"   OFF \
    "homepage"               "[Dashboard]   Homepage — modern widget-based dashboard"                ON  \
    "dashy"                  "[Dashboard]   Dashy — feature-rich self-hosted startpage"              OFF \
    "autoheal"               "[Automation]  Autoheal — auto-restart unhealthy containers"            ON  \
    "watchtower"             "[Automation]  Watchtower — automatic Docker image updates"              ON  \
    "diun"                   "[Automation]  Diun — image update notifier (alerts, no auto-pull)"     ON  \
    "cloudflared"            "[Tunnel]      Cloudflared — Cloudflare Tunnel (requires CF account)"   OFF \
    "pangolin"               "[Tunnel]      Pangolin — self-hosted tunnel (no Cloudflare needed)"    OFF \
    "adguardhome"            "[DNS]         AdGuard Home + Unbound — network-wide ad/tracker DNS"    OFF \
    "netbird"                "[VPN]         NetBird — WireGuard-based zero-config VPN mesh"          OFF \
    "watch-your-lan"         "[Network]     Watch Your LAN — network device discovery"               OFF \
    "uptime-kuma"            "[Monitoring]  Uptime Kuma — service uptime & status pages"             ON  \
    "dozzle"                 "[Monitoring]  Dozzle — real-time Docker log viewer"                    ON  \
    "glances"                "[Monitoring]  Glances — system resource monitoring"                    OFF \
    "speedtest-tracker"      "[Monitoring]  Speedtest Tracker — automated speed logging"             OFF \
    "linux-update-dashboard" "[Monitoring]  Linux Update Dashboard — OS package tracker"             OFF \
    "monocker"               "[Monitoring]  Monocker — container state change notifications"         OFF \
    "portracker"             "[Monitoring]  PortTracker — open port monitoring"                      OFF \
    "paperless-ngx"          "[Documents]   Paperless-NGX — document scanning & management"         OFF \
    "hoarder"                "[Documents]   Hoarder — bookmark & read-later collection"              OFF \
    "homebox"                "[Productivity] Homebox — home inventory & asset management"            OFF \
    "firefly-iii"            "[Finance]     Firefly III — personal finance & budgeting"              OFF \
    "vikunja"                "[Productivity] Vikunja — to-do lists & project management"             OFF \
    "stirling-pdf"           "[Utility]     Stirling PDF — PDF manipulation & conversion"            OFF \
    "apprise"                "[Utility]     Apprise — unified notification service hub"              OFF \
    "stalwart-mail"          "[Mail]        Stalwart Mail — full SMTP / IMAP / POP3 server"          OFF \
    3>&1 1>&2 2>&3) || {
      echo
      die "Selection cancelled by user."
    }

  local app
  for app in $raw; do
    SELECTED_APPS+=("${app//\"/}")
  done
}

_select_text() {
  echo -e "  ${YELLOW}whiptail not found${NC} — using text-based selection."
  echo
  local -a ALL_APPS=(
    crowdsec          crowdsec-console   openappsec         authelia
    geoip-blocker     anubis             vaultwarden        bitwarden
    homepage          dashy              autoheal           watchtower
    diun              cloudflared        pangolin           adguardhome
    netbird           watch-your-lan     uptime-kuma        dozzle
    glances           speedtest-tracker  linux-update-dashboard  monocker
    portracker        paperless-ngx      hoarder            homebox
    firefly-iii       vikunja            stirling-pdf       apprise
    stalwart-mail
  )
  # 1-based indexes of defaults (matching the ON items in whiptail above)
  local -a DEFAULT_IDX=(1 2 3 4 5 6 7 9 11 12 13 19 20)

  local i=1
  for app in "${ALL_APPS[@]}"; do
    local mark="   "
    for d in "${DEFAULT_IDX[@]}"; do
      [[ $d -eq $i ]] && mark="[*]"
    done
    printf "  %2d) %s  %s\n" "$i" "$mark" "$app"
    (( i++ ))
  done

  echo
  echo -e "  ${BOLD}[*]${NC} = recommended default"
  echo -e "  Enter numbers (space-separated), ${BOLD}all${NC} for everything,"
  echo -e "  or press ${BOLD}ENTER${NC} to use the recommended defaults."
  echo
  printf "${YELLOW}?${NC} Your selection: "
  read -r selection < /dev/tty

  if [[ -z "$selection" ]]; then
    for d in "${DEFAULT_IDX[@]}"; do
      SELECTED_APPS+=("${ALL_APPS[$((d-1))]}")
    done
  elif [[ "${selection,,}" == "all" ]]; then
    SELECTED_APPS=("${ALL_APPS[@]}")
  else
    for num in $selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#ALL_APPS[@]} )); then
        SELECTED_APPS+=("${ALL_APPS[$((num-1))]}")
      else
        warn "  Ignoring invalid entry: $num"
      fi
    done
  fi
}

step_select_apps() {
  hr
  echo -e "${BOLD}STEP 3 / 5 — Application Selection${NC}"
  hr

  if command -v whiptail &>/dev/null; then
    _select_whiptail
  else
    _select_text
  fi

  echo
  if [[ ${#SELECTED_APPS[@]} -eq 0 ]]; then
    warn "No optional apps selected. Only core infrastructure will be installed."
  else
    ok "Selected (${#SELECTED_APPS[@]}): ${SELECTED_APPS[*]}"
  fi
  echo
}

# ─── Step 4: Download ─────────────────────────────────────────────────────────
step_download() {
  hr
  echo -e "${BOLD}STEP 4 / 5 — Download Project${NC}"
  hr
  echo -e "  Repository : ${CYAN}${REPO_URL}${NC}"
  echo -e "  Destination: ${CYAN}${INSTALL_DIR}${NC}"
  echo
  ask_yn "Download HomeLab from GitHub?" y || die "Aborted by user."

  # If it is already a git repo, just pull
  if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Existing git repo found — pulling latest..."
    git -C "$INSTALL_DIR" pull --ff-only
    ok "Updated."
    echo
    return 0
  fi

  mkdir -p "$INSTALL_DIR"

  if command -v git &>/dev/null; then
    info "Cloning repository..."
    git clone --depth=1 "${REPO_URL}.git" "$INSTALL_DIR"
  else
    warn "git not found — downloading ZIP archive instead..."
    local zip="/tmp/homelab-$$.zip" tmp="/tmp/homelab-ext-$$"
    curl -fsSL "${REPO_URL}/archive/refs/heads/main.zip" -o "$zip" \
      || die "ZIP download failed."

    info "Extracting archive..."
    mkdir -p "$tmp"
    if command -v unzip &>/dev/null; then
      unzip -q "$zip" -d "$tmp"
    else
      python3 -c \
        "import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" \
        "$zip" "$tmp" \
        || die "Extraction failed (install unzip or python3)."
    fi

    shopt -s dotglob
    mv "$tmp"/HomeLab-main/* "$INSTALL_DIR/"
    shopt -u dotglob
    rm -rf "$zip" "$tmp"
  fi

  # Remove files that have no place in a production install
  local -a unwanted=(
    .git .gitattributes .gitignore
    handoff.md HOMELAB_COMPLETE_GUIDE.md QUICK_REFERENCE.md LICENSE
  )
  for item in "${unwanted[@]}"; do
    rm -rf "${INSTALL_DIR:?}/$item"
  done

  ok "Repository ready at $INSTALL_DIR"
  echo
}

# ─── Step 5: Configure & Start ────────────────────────────────────────────────
step_configure() {
  hr
  echo -e "${BOLD}STEP 5 / 5 — Configure & Start${NC}"
  hr

  local env_file="$INSTALL_DIR/.env"
  if [[ -f "$env_file" ]]; then
    info "Generating missing secrets in .env..."
    cp "$env_file" "${env_file}.bak"
    local count=0
    while IFS= read -r line; do
      if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=$ ]]; then
        local key="${BASH_REMATCH[1]}"
        if [[ "$key" =~ (SECRET|PASSWORD|KEY|TOKEN|PASS|HASH) ]]; then
          local secret; secret=$(gen_secret)
          # Use | as delimiter to avoid issues with / in secrets
          sed -i "s|^${key}=\$|${key}=${secret}|" "$env_file"
          info "  Generated: $key"
          (( count++ )) || true
        fi
      fi
    done < "${env_file}.bak"

    if (( count > 0 )); then
      ok "$count secret(s) generated. Backup: ${env_file}.bak"
    else
      ok "All secrets are already configured."
    fi
    warn "Review ${INSTALL_DIR}/.env — set your domain, Cloudflare tokens, and other site-specific values before services will work."
  else
    warn ".env file not found — skipping auto-configuration."
  fi
  echo
}

step_start() {
  # Determine docker compose command
  local DC
  if docker compose version &>/dev/null 2>&1; then
    DC="docker compose"
  elif command -v docker-compose &>/dev/null; then
    DC="docker-compose"
  else
    die "docker compose not found. Cannot start services."
  fi

  cd "$INSTALL_DIR"

  # ── Root-compose services (always-on core + selected apps) ──────────────────
  local root_services=("postgres" "redis" "docker-proxy" "caddy")
  local standalone_apps=()   # apps that need their own compose file

  for app in "${SELECTED_APPS[@]}"; do
    case "$app" in
      cloudflared|pangolin)
        standalone_apps+=("$app")
        ;;
      *)
        read -ra svcs <<< "$(get_services "$app")"
        root_services+=("${svcs[@]}")
        ;;
    esac
  done

  echo -e "  Core services always started:"
  echo -e "    ${CYAN}postgres  redis  docker-proxy  caddy${NC}"
  if [[ ${#SELECTED_APPS[@]} -gt 0 ]]; then
    echo -e "  Optional services:"
    echo -e "    ${CYAN}${SELECTED_APPS[*]}${NC}"
  fi
  echo

  # Remind about open-appsec token if selected (not blocking — works without one in standalone mode)
  if printf '%s\n' "${SELECTED_APPS[@]}" | grep -q "^openappsec$"; then
    echo
    warn "open-appsec: set APPSEC_AGENT_TOKEN in openappsec/.env to connect to"
    warn "the cloud Web UI at https://my.openappsec.io"
    warn "Without a token, add COMPOSE_PROFILES=standalone to openappsec/.env"
    warn "to enable local threat learning instead."
    echo
  fi

  ask_yn "Start all selected services now?" y || {
    info "Skipping startup. To start later:"
    echo "  cd $INSTALL_DIR"
    echo "  sudo docker compose up -d ${root_services[*]}"
    return 0
  }

  # Pull all images, skipping any that fail (private, auth-gated, or unavailable).
  # --ignore-pull-failures means one denied image won't abort the whole pull.
  info "Pulling images (this may take several minutes)..."
  sudo $DC pull --ignore-pull-failures "${root_services[@]}" || true
  echo

  # --pull never (v2) / --no-pull (v1): use only locally cached images so a
  # single missing image does not abort the entire stack.
  local pull_flag="--pull never"
  [[ "$DC" == "docker-compose" ]] && pull_flag="--no-pull"

  info "Starting core + selected services..."
  local up_exit=0
  sudo $DC up -d $pull_flag "${root_services[@]}" || up_exit=$?
  if [[ $up_exit -eq 0 ]]; then
    ok "Services started."
  else
    warn "Some services failed to start (exit $up_exit)."
    warn "Services whose images could not be pulled were skipped."
    warn "Check status with: sudo docker compose ps"
  fi

  # ── Standalone apps (cloudflared, pangolin) ──────────────────────────────────
  for app in "${standalone_apps[@]}"; do
    local compose_file="$INSTALL_DIR/$app/compose.yaml"
    if [[ -f "$compose_file" ]]; then
      info "Starting $app (standalone compose)..."
      sudo $DC -f "$compose_file" pull --ignore-pull-failures 2>/dev/null || true
      sudo $DC -f "$compose_file" up -d $pull_flag || warn "$app failed to start — check logs."
      ok "$app started."
    else
      warn "Compose file not found for $app — skipping ($compose_file)."
    fi
  done

  echo
}

# ─── Summary ──────────────────────────────────────────────────────────────────
summary() {
  hr
  echo -e "${GREEN}${BOLD}"
  cat << 'DONE'
  ╔══════════════════════════════════════════════════╗
  ║        HomeLab installation complete!            ║
  ╚══════════════════════════════════════════════════╝
DONE
  echo -e "${NC}"
  echo -e "  Install dir  : ${CYAN}${INSTALL_DIR}${NC}"
  echo -e "  Apps selected: ${CYAN}${SELECTED_APPS[*]:-none (core only)}${NC}"
  echo
  echo -e "  ${BOLD}Useful commands${NC}"
  echo -e "    ${CYAN}cd ${INSTALL_DIR}${NC}"
  echo -e "    ${CYAN}sudo docker compose ps${NC}                      — check status"
  echo -e "    ${CYAN}sudo docker compose logs -f <service>${NC}       — view logs"
  echo -e "    ${CYAN}sudo docker compose restart <service>${NC}       — restart one"
  echo -e "    ${CYAN}sudo docker compose down${NC}                    — stop everything"
  echo
  echo -e "  ${BOLD}Required before services work correctly${NC}"
  echo -e "    1. Edit ${CYAN}${INSTALL_DIR}/.env${NC} — set your domain name, SMTP creds, API tokens"
  echo -e "    2. Configure Caddy routes in ${CYAN}${INSTALL_DIR}/caddy/${NC}"

  if printf '%s\n' "${SELECTED_APPS[@]}" | grep -qx "cloudflared"; then
    echo -e "    3. Set ${CYAN}CLOUDFLARE_TUNNEL_TOKEN${NC} in .env and restart cloudflared"
  fi
  if printf '%s\n' "${SELECTED_APPS[@]}" | grep -qx "authelia"; then
    echo -e "    3. Review Authelia configuration in ${CYAN}${INSTALL_DIR}/authelia/${NC}"
  fi
  if printf '%s\n' "${SELECTED_APPS[@]}" | grep -qx "crowdsec"; then
    echo -e "    3. Register your CrowdSec instance at ${CYAN}https://app.crowdsec.net${NC}"
  fi
  echo
  hr
  echo

  # Self-delete — the installer has no use after setup is complete
  local self="${INSTALL_DIR}/start.sh"
  if [[ -f "$self" ]]; then
    rm -f "$self"
    info "Installer removed: $self"
  fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  banner
  check_prereqs
  step_docker
  step_dir
  step_select_apps
  step_download
  step_configure
  step_start
  summary
}

main "$@"
