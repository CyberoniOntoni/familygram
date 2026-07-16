# Shared helpers for FamilyGram Docker installers (FamilyGram Server + web client).
# Sourced by deploy/install.sh — do not execute directly.

installer_lib_init() {
  if [[ -t 1 ]] || [[ -w /dev/tty ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_CYAN=$'\033[36m'
    C_RED=$'\033[31m'
  else
    C_RESET='' C_BOLD='' C_DIM='' C_GREEN='' C_YELLOW='' C_CYAN='' C_RED=''
  fi
}

have_tty() {
  [[ -r /dev/tty ]] && [[ -w /dev/tty ]]
}

tty_enable_echo_on_fd() {
  # stty must target the same fd used by read — call inside { } < /dev/tty blocks
  stty sane 2>/dev/null || true
  stty echo icanon 2>/dev/null || true
}

interactive_tty() {
  [[ "${NON_INTERACTIVE}" != true ]] && have_tty
}

tty_write() {
  # shellcheck disable=SC2059
  printf "$@" > /dev/tty
}

ui_printf() {
  if interactive_tty; then
    tty_write "$@"
  else
    # shellcheck disable=SC2059
    printf "$@"
  fi
}

ui_warn() {
  if interactive_tty; then
    tty_write "$@"
  else
    # shellcheck disable=SC2059
    printf "$@" >&2
  fi
}

hr()  { ui_printf '%s\n' "────────────────────────────────────────────────────────────"; }
log() { ui_printf '%s==>%s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
warn() { ui_warn '%s!!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*"; }
die()  { ui_warn '%sERROR:%s %s\n' "${C_RED}" "${C_RESET}" "$*"; exit 1; }

banner() {
  ui_printf '\n%s' "${C_CYAN}${C_BOLD}"
  if interactive_tty; then
    cat <<'EOF' > /dev/tty
 ███████╗ █████╗ ███╗   ███╗██╗██╗  ██╗   ██╗ ██████╗ ██████╗  █████╗ ███╗   ███╗
 ██╔════╝██╔══██╗████╗ ████║██║██║  ╚██╗ ██╔╝██╔════╝ ██╔══██╗██╔══██╗████╗ ████║
 █████╗  ███████║██╔████╔██║██║██║   ╚████╔╝ ██║  ███╗██████╔╝███████║██╔████╔██║
 ██╔══╝  ██╔══██║██║╚██╔╝██║██║██║    ╚██╔╝  ██║   ██║██╔══██╗██╔══██║██║╚██╔╝██║
 ██║     ██║  ██║██║ ╚═╝ ██║██║███████╗██║   ╚██████╔╝██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═╝     ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
EOF
  else
    cat <<'EOF'
 ███████╗ █████╗ ███╗   ███╗██╗██╗  ██╗   ██╗ ██████╗ ██████╗  █████╗ ███╗   ███╗
 ██╔════╝██╔══██╗████╗ ████║██║██║  ╚██╗ ██╔╝██╔════╝ ██╔══██╗██╔══██╗████╗ ████║
 █████╗  ███████║██╔████╔██║██║██║   ╚████╔╝ ██║  ███╗██████╔╝███████║██╔████╔██║
 ██╔══╝  ██╔══██║██║╚██╔╝██║██║██║    ╚██╔╝  ██║   ██║██╔══██╗██╔══██║██║╚██╔╝██║
 ██║     ██║  ██║██║ ╚═╝ ██║██║███████╗██║   ╚██████╔╝██║  ██║██║  ██║██║ ╚═╝ ██║
 ╚═╝     ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚══════╝╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
EOF
  fi
  ui_printf '%s\n' "${C_RESET}"
  ui_printf '  %sFamilyGram unified installer%s\n' "${C_BOLD}" "${C_RESET}"
  ui_printf '  %sFamilyGram Server + web client via Docker Compose%s\n\n' "${C_DIM}" "${C_RESET}"
}

step() {
  ui_printf '\n%s Step %d/%d — %s%s\n' "${C_CYAN}${C_BOLD}" "$1" "$2" "$3" "${C_RESET}"
  hr
}

escape_sed_repl() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//&/\\&}"
  s="${s//|/\\|}"
  printf '%s' "$s"
}

sanitize_ip_input() {
  local s="$1"
  s="$(trim_line "$s")"
  s="${s//[^0-9.]/}"
  printf '%s' "$s"
}

is_ipv4() {
  local ip="$1"
  local a b c d extra o
  local re='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

  ip="$(sanitize_ip_input "$ip")"
  [[ -n "$ip" ]] || return 1
  [[ "$ip" =~ $re ]] || return 1

  IFS='.' read -r a b c d extra <<< "${ip}."
  [[ -n "$a" && -n "$b" && -n "$c" && -n "$d" && -z "$extra" ]] || return 1

  for o in "$a" "$b" "$c" "$d"; do
    [[ "$o" =~ ^[0-9]{1,3}$ ]] || return 1
    # 10#${o} forces decimal (08/09 octets); braces are required in bash arithmetic
    if ((10#${o} > 255)); then
      return 1
    fi
  done
  return 0
}

is_domain() {
  local d re
  d="$(trim_line "$1")"
  re='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
  [[ "$d" =~ $re ]] || return 1
  return 0
}

is_port() {
  local p="$1"
  local re='^[0-9]+$'
  [[ "$p" =~ $re ]] || return 1
  if (( p < 1 || p > 65535 )); then
    return 1
  fi
  return 0
}

is_verify_code() {
  local code="$1"
  code="$(trim_line "$code")"
  [[ "$code" =~ ^[0-9]{4,8}$ ]] || return 1
  return 0
}

# Format WAN port for router/firewall tables: 5348(TCP&UDP), 49152-49172(UDP), etc.
port_with_proto() {
  local port="$1"
  local proto="$2"
  printf '%s(%s)' "$port" "$proto"
}

is_yes() {
  case "${1,,}" in
    true|yes|1) return 0 ;;
    *) return 1 ;;
  esac
}

detect_lan_ip() {
  local ip=""
  ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}')"
  ip="$(trim_line "$ip")"
  if is_ipv4 "$ip"; then
    printf '%s' "$ip"
    return 0
  fi
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  ip="$(trim_line "$ip")"
  if is_ipv4 "$ip"; then
    printf '%s' "$ip"
    return 0
  fi
  ip="$(ip -4 -o addr show scope global up 2>/dev/null | awk '{print $4}' | head -n1 | cut -d/ -f1)"
  ip="$(trim_line "$ip")"
  if is_ipv4 "$ip"; then
    printf '%s' "$ip"
    return 0
  fi
  return 1
}

fetch_url() {
  local url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -4 -fsSL --max-time 8 "$url" 2>/dev/null | head -n1
    return 0
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO- --timeout=8 "$url" 2>/dev/null | head -n1
    return 0
  fi
  return 1
}

detect_public_ip() {
  local ip="" url
  local urls=(
    "https://api4.ipify.org"
    "https://ifconfig.me/ip"
    "https://icanhazip.com"
    "https://checkip.amazonaws.com"
  )
  for url in "${urls[@]}"; do
    ip="$(fetch_url "$url" || true)"
    ip="$(trim_line "$ip")"
    ip="$(sanitize_ip_input "$ip")"
    if is_ipv4 "$ip"; then
      printf '%s' "$ip"
      return 0
    fi
  done
  return 1
}

show_detected_ips() {
  local detected_lan="$1"
  local detected_public="$2"

  ui_printf '%s\n' "Auto-detected addresses (suggestions only — you must type your values):"
  if [[ -n "$detected_public" ]]; then
    ui_printf '  %sPublic WAN IP:%s %s\n' "${C_DIM}" "${C_RESET}" "${detected_public}"
  else
    ui_printf '  %sPublic WAN IP:%s not detected (check your router or https://ifconfig.me)\n' "${C_DIM}" "${C_RESET}"
  fi
  if [[ -n "$detected_lan" ]]; then
    ui_printf '  %sLAN / host IP:%s %s\n' "${C_DIM}" "${C_RESET}" "${detected_lan}"
  else
    ui_printf '  %sLAN / host IP:%s not detected (run: ip -4 route get 1.1.1.1)\n' "${C_DIM}" "${C_RESET}"
  fi
  ui_printf '%s\n' "Press Enter on an empty field will NOT use these — type each IP yourself."
  ui_printf '\n'
}

setup_interactive_stdin() {
  if [[ "${NON_INTERACTIVE}" == true ]]; then
    return 0
  fi
  if have_tty || [[ -t 0 ]]; then
    return 0
  fi
  die "No interactive terminal.

Do NOT pipe this script (curl ... | bash) — that steals stdin and skips prompts.

Instead:
  curl -fsSL https://raw.githubusercontent.com/CyberoniOntoni/familygram/main/deploy/install.sh -o install.sh
  sudo bash install.sh

Or pass all values explicitly:
  PUBLIC_IP=... LAN_IP=... BOT_TOKEN=... sudo bash install.sh --non-interactive"
}

trim_line() {
  local s="$1"
  s="${s//$'\r'/}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

read_with_prompt() {
  local __var="$1"
  local __prompt="$2"
  local __line=""

  # Prompt + read on the same tty with echo enabled (stdin and stdout both /dev/tty).
  # Reading < /dev/tty without this breaks character echo on many consoles (SSH, LXC, sudo).
  if interactive_tty; then
    {
      tty_enable_echo_on_fd
      printf '%s' "$__prompt"
      IFS= read -r __line
    } < /dev/tty > /dev/tty
  elif [[ -t 0 ]]; then
    tty_enable_echo_on_fd
    printf '%s' "$__prompt" >&2
    IFS= read -r __line || die "Could not read input."
  else
    die "No terminal for input. Connect with: ssh -t root@host"
  fi
  __line="$(trim_line "$__line")"
  printf -v "$__var" '%s' "$__line"
}

prompt() {
  local var_name="$1" prompt_text="$2" default="${3:-}" validate="${4:-}"
  local input="" display_default=""

  if [[ "${NON_INTERACTIVE}" == true ]]; then
    if [[ -z "${!var_name:-}" ]]; then
      if [[ -n "$default" ]]; then
        printf -v "$var_name" '%s' "$default"
      else
        die "Missing required value for ${var_name} in non-interactive mode"
      fi
    fi
    return 0
  fi

  if [[ -n "$default" ]]; then
    display_default=" ${C_DIM}[${default}]${C_RESET}"
  fi

  while true; do
    read_with_prompt input "  ${prompt_text}${display_default}: "
    input="${input:-$default}"
    if [[ -z "$input" ]]; then
      warn "This field is required."
      continue
    fi
    if [[ -n "$validate" ]]; then
      if ! "$validate" "$input"; then
        if [[ "$validate" == "is_ipv4" ]]; then
          warn "Invalid IPv4 — enter four dot-separated numbers (0-255 per octet)"
        elif [[ "$validate" == "is_domain" ]]; then
          warn "Invalid domain — use e.g. tg.example.com (no https://)"
        else
          warn "Invalid value — try again."
        fi
        continue
      fi
      if [[ "$validate" == "is_ipv4" ]]; then
        input="$(sanitize_ip_input "$input")"
      fi
    fi
    printf -v "$var_name" '%s' "$input"
    break
  done
}

prompt_yes_no() {
  local var_name="$1" prompt_text="$2" default="${3:-yes}"
  local input="" hint="Y/n"

  if [[ "${NON_INTERACTIVE}" == true ]]; then
    [[ -n "${!var_name:-}" ]] || printf -v "$var_name" '%s' "$default"
    return 0
  fi

  [[ "$default" == "no" ]] && hint="y/N"

  while true; do
    read_with_prompt input "  ${prompt_text} ${C_DIM}(${hint})${C_RESET}: "
    input="${input:-$default}"
    case "${input,,}" in
      y|yes)  printf -v "$var_name" '%s' "yes"; break ;;
      n|no)   printf -v "$var_name" '%s' "no"; break ;;
      *) warn "Answer y or n." ;;
    esac
  done
}

confirm() {
  local prompt_text="$1" default="${2:-yes}"
  if [[ "${NON_INTERACTIVE}" == true ]]; then
    return 0
  fi
  local input=""
  read_with_prompt input "  ${prompt_text} (Y/n): "
  input="${input:-$default}"
  [[ "${input,,}" == "y" || "${input,,}" == "yes" ]]
}

check_lxc_prereqs() {
  if [[ "${INSTALLER_PROFILE:-}" != "lxc" ]]; then
    return 0
  fi
  if [[ -f /.dockerenv ]] || grep -qE 'lxc|container' /proc/1/cgroup 2>/dev/null; then
    log "LXC/container environment detected"
    if ! grep -q '^Features:.*nesting' /proc/self/status 2>/dev/null; then
      warn "LXC nesting may be disabled — Docker can fail."
      warn "On Proxmox host: pct set <CTID> -features nesting=1,keyctl=1"
      warn "Then restart the container."
    fi
  fi
}

maybe_self_update() {
  local repo_script="${LOCAL_REPO_ROOT}/deploy/install.sh"
  [[ -f "${repo_script}" ]] || return 0
  [[ -d "${LOCAL_REPO_ROOT}/.git" ]] || return 0
  [[ "${INSTALLER_SELF_UPDATED:-}" == "1" ]] && return 0

  local hash_before hash_after
  hash_before="$(sha256sum "${repo_script}" 2>/dev/null | awk '{print $1}')" || return 0

  git -C "${LOCAL_REPO_ROOT}" fetch origin "${REPO_BRANCH}" 2>/dev/null || true
  git -C "${LOCAL_REPO_ROOT}" checkout "${REPO_BRANCH}" 2>/dev/null || true
  git -C "${LOCAL_REPO_ROOT}" pull --ff-only origin "${REPO_BRANCH}" 2>/dev/null || true

  hash_after="$(sha256sum "${repo_script}" 2>/dev/null | awk '{print $1}')" || return 0
  if [[ "${hash_before}" != "${hash_after}" ]]; then
    log "Installer updated from git — restarting..."
    export INSTALLER_SELF_UPDATED=1
    exec bash "${repo_script}" "$@"
  fi
}

install_system_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    log "Installing system packages (apt)..."
    apt-get update -qq
    apt-get install -y -qq \
      ca-certificates curl wget git gnupg openssl iproute2 apt-transport-https
    if is_yes "${DO_FIREWALL}"; then
      apt-get install -y -qq ufw || warn "UFW not available — skipping firewall packages"
    fi
    return 0
  fi
  warn "apt-get not found — ensure curl, wget, git, and openssl are installed"
}

node_major_version() {
  local ver major
  if ! command -v node >/dev/null 2>&1; then
    printf '0'
    return 0
  fi
  ver="$(node -v 2>/dev/null || true)"
  ver="${ver#v}"
  major="${ver%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]]; then
    printf '%s' "$major"
  else
    printf '0'
  fi
}

load_nvm() {
  export NVM_DIR="${NVM_DIR:-/root/.nvm}"
  if [[ -s "${NVM_DIR}/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "${NVM_DIR}/nvm.sh"
    return 0
  fi
  return 1
}

install_nvm_node() {
  local nvm_version="0.40.5"
  local node_version="24"
  export NVM_DIR="${NVM_DIR:-/root/.nvm}"

  if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
    log "Installing nvm ${nvm_version}..."
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${nvm_version}/install.sh" | bash
  else
    log "nvm already present at ${NVM_DIR}"
  fi

  load_nvm || die "nvm failed to load from ${NVM_DIR}/nvm.sh"

  log "Installing Node.js ${node_version} via nvm (package requires ^22.6 or ^24)..."
  nvm install "${node_version}"
  nvm alias default "${node_version}"
  nvm use default

  local node_bin npm_bin npx_bin
  node_bin="$(nvm which current)"
  npm_bin="$(dirname "${node_bin}")/npm"
  npx_bin="$(dirname "${node_bin}")/npx"
  ln -sf "${node_bin}" /usr/local/bin/node
  ln -sf "${npm_bin}" /usr/local/bin/npm
  ln -sf "${npx_bin}" /usr/local/bin/npx

  cat > /etc/profile.d/familygram-nvm.sh <<EOF
# FamilyGram installer — load nvm Node.js for login shells
export NVM_DIR="${NVM_DIR}"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
EOF
  chmod 644 /etc/profile.d/familygram-nvm.sh
}

ensure_nodejs() {
  local major required_major=22
  major="$(node_major_version)"

  if (( major >= required_major )); then
    log "Node.js OK: $(node -v) (npm $(npm -v 2>/dev/null || echo n/a))"
    return 0
  fi

  if (( major > 0 )); then
    warn "Node.js v${major}.x is too old (need ^22.6) — upgrading via nvm"
  else
    log "Node.js not found — installing via nvm"
  fi

  install_nvm_node

  major="$(node_major_version)"
  if (( major < required_major )); then
    die "Node.js install failed — still at $(node -v 2>/dev/null || echo missing)"
  fi
  log "Node.js ready: $(node -v) (npm $(npm -v))"
}

install_prerequisites() {
  install_system_deps
  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    ensure_nodejs
  else
    log "Skipping Node.js check (FamilyGram Web disabled)"
  fi
  install_docker
  ensure_compose
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
    return 0
  fi
  if ! is_yes "${INSTALL_DOCKER}"; then
    die "Docker is not installed. Re-run and choose to install Docker, or install it manually."
  fi
  log "Installing Docker (official script)..."
  curl -fsSL https://get.docker.com | sh
}

ensure_compose() {
  docker compose version >/dev/null 2>&1 || die "docker compose plugin missing — install docker-compose-plugin"
}

clone_or_update_repo() {
  log "Cloning or updating FamilyGram (${REPO_BRANCH}) → ${INSTALL_DIR}"
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "${INSTALL_DIR}" fetch origin
    git -C "${INSTALL_DIR}" checkout "${REPO_BRANCH}"
    git -C "${INSTALL_DIR}" pull --ff-only origin "${REPO_BRANCH}" || warn "git pull failed — using existing checkout"
  else
    git clone --branch "${REPO_BRANCH}" --depth 1 "${REPO_URL}" "${INSTALL_DIR}"
  fi
}

set_env() {
  local key="$1" val="$2" escaped
  escaped="$(escape_sed_repl "$val")"
  if grep -q "^${key}=" .env; then
    sed -i "s|^${key}=.*|${key}=${escaped}|" .env
  else
    printf '%s=%s\n' "${key}" "${val}" >> .env
  fi
}

write_env_file() {
  log "Writing ${COMPOSE_DIR}/.env ..."
  if [[ -f .env ]]; then
    cp .env ".env.bak.$(date +%s)"
    warn "Existing .env backed up before overwrite"
  fi
  cp .env.example .env

  local rabbit_pw minio_sk access_hash msg_key idx_key
  rabbit_pw="$(openssl rand -hex 24)"
  minio_sk="$(openssl rand -hex 24)"
  access_hash="$(openssl rand -hex 32)"
  msg_key="$(openssl rand -base64 32)"
  idx_key="$(openssl rand -base64 32)"

  set_env RabbitMQ__Connections__Default__Password "$rabbit_pw"
  set_env Minio__SecretKey "$minio_sk"
  set_env App__AccessHashSecretKey "$access_hash"
  set_env App__EncryptionConfig__MessageKeys__0__Key "$msg_key"
  set_env App__EncryptionConfig__IndexKeys__0__Key "$idx_key"

  set_env App__Brand "$BRAND"
  set_env App__WelcomeMsg "Welcome to ${BRAND}! Your account has been created."
  set_env App__SendWelcomeMessageAfterUserSignIn "True"
  set_env App__PasskeyRpId "$PASSKEY_DOMAIN"
  set_env App__PasskeyRpName "$BRAND"
  if [[ "${ENABLE_BOT}" == "yes" ]]; then
    set_env BOT_TOKEN "$BOT_TOKEN"
    set_env TelegramBotSms__Enabled "true"
    set_env App__FixedVerifyCode ""
  else
    set_env BOT_TOKEN ""
    set_env TelegramBotSms__Enabled "false"
    set_env App__FixedVerifyCode "$FIXED_VERIFY_CODE"
  fi

  set_env App__Servers__0__Port "$PORT_MT1"
  set_env App__Servers__1__Port "$PORT_MT2"
  set_env App__Servers__2__Port "$PORT_MT3"
  set_env App__Servers__3__Port "$PORT_MT4"
  set_env App__Servers__4__Port "$PORT_HTTPS"
  set_env App__Servers__5__Port "$PORT_HTTPS_ALT"

  set_env App__WebRtcConnections__0__Ip "$PUBLIC_IP"
  set_env App__WebRtcConnections__0__Port "$PORT_STUN"
  set_env App__WebRtcConnections__0__Turn "True"
  set_env App__WebRtcConnections__0__Stun "True"
  set_env App__WebRtcConnections__0__UserName "${TURN_USER:-testgram}"
  set_env App__WebRtcConnections__0__Password "$TURN_PASS"

  set_env TwilioSms__Enabled "False"
  set_env TwilioSms__AccountSId ""
  set_env TwilioSms__AuthToken ""
  set_env TwilioSms__FromNumber ""
  set_env TwilioSms__MessagingServiceSId ""

  if [[ "${ENABLE_RTMP}" == "yes" ]]; then
    set_env App__RtmpStreamUrl "rtmp://${PUBLIC_IP}:${PORT_RTMP:-1935}/live"
    set_env App__RtmpHlsUrl "http://${PUBLIC_IP}:${PORT_RTMP_HLS:-8888}/hls"
  else
    set_env App__RtmpStreamUrl ""
    set_env App__RtmpHlsUrl ""
  fi

  local i
  for i in 0 1 2 3; do
    set_env "App__DcOptions__${i}__IpAddress" "$PUBLIC_IP"
  done
  set_env App__DcOptions__0__Port "$PORT_MT1"
  set_env App__DcOptions__1__Port "$PORT_MT2"
  set_env App__DcOptions__2__Port "$PORT_MT3"
  set_env App__DcOptions__3__Port "$PORT_MT4"

  set_env RTMP_PORT "${PORT_RTMP:-1935}"
  set_env RTMP_HLS_PORT "${PORT_RTMP_HLS:-8888}"
  set_env PORT_STUN "$PORT_STUN"
  set_env PORT_RELAY_MIN "$PORT_RELAY_MIN"
  set_env PORT_RELAY_MAX "$PORT_RELAY_MAX"

  set_env COTURN_EXTERNAL_IP "$PUBLIC_IP"
  set_env TELEGRAM_API_ID "$TELEGRAM_API_ID"
  set_env TELEGRAM_API_HASH "$TELEGRAM_API_HASH"
  set_env WEB_HOST_PORT "$WEB_HOST_PORT"
  set_env WEB_CONTAINER_PORT "$WEB_CONTAINER_PORT"
  set_env WEB_APP_NAME "${WEB_APP_NAME:-FamilyGram Web}"
  set_env WEB_APP_TITLE "${WEB_APP_TITLE:-${BRAND}}"

  if [[ "${ENABLE_WEB}" == "yes" && -n "${WEB_DOMAIN}" ]]; then
    local web_base="https://${WEB_DOMAIN}/"
    set_env WEB_DOMAIN "$WEB_DOMAIN"
    set_env WEB_BASE_URL "$web_base"
  fi
}

write_compose_override() {
  local override="${COMPOSE_DIR}/docker-compose.override.yml"
  if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
    log "Passkey enabled — publishing HTTPS gateway port ${PORT_HTTPS} on host (docker-compose.override.yml)"
    cat > "${override}" <<EOF
# Generated by FamilyGram installer — passkey (WebAuthn) HTTPS gateway on host.
# Port ${PORT_HTTPS_ALT} (HTTP/WS) stays Docker-internal; web UI uses familygram-web /apiws.
services:
  gateway-server:
    ports:
      - "${PORT_HTTPS}:${PORT_HTTPS}"
EOF
  elif [[ -f "${override}" ]]; then
    rm -f "${override}"
    log "Passkey disabled — removed docker-compose.override.yml (gateway HTTPS not on host)"
  fi
}

patch_compose() {
  # Coturn ports/credentials come from .env (PORT_STUN, PORT_RELAY_*, App__WebRtcConnections__*).
  # Kept for compatibility with verify-installer backups; no tracked compose edits.
  :
}

prepare_data_dirs() {
  log "Preparing data directories..."
  mkdir -p data/mytelegram data/bot geoip data/redis data/rabbitmq \
    data/mongo/db data/mongo/configdb data/minio data/coturn data/rtmp \
    data/mytelegram/data-seeder/downloads/langpacks
  chmod -R a+w data

  local langpack_src="${COMPOSE_DIR}/langpacks"
  local langpack_dst="${COMPOSE_DIR}/data/mytelegram/data-seeder/downloads/langpacks"
  if [[ -d "${langpack_src}" ]]; then
    log "Installing language pack files for data-seeder..."
    mkdir -p "${langpack_dst}"
    cp -a "${langpack_src}/." "${langpack_dst}/"
  fi
}

save_install_summary() {
  SUMMARY_FILE="${INSTALL_DIR}/deploy/last-install-config.txt"
  mkdir -p "${INSTALL_DIR}/deploy"
  cat > "${SUMMARY_FILE}" <<EOF
# FamilyGram install config — $(date -Iseconds)
INSTALLER_VERSION=${INSTALLER_VERSION}
PUBLIC_IP=${PUBLIC_IP}
LAN_IP=${LAN_IP}
BRAND=${BRAND}
PASSKEY_DOMAIN=${PASSKEY_DOMAIN}
ENABLE_PASSKEY=${ENABLE_PASSKEY}
ENABLE_RTMP=${ENABLE_RTMP}
PORT_MT1=${PORT_MT1}
PORT_MT2=${PORT_MT2}
PORT_MT3=${PORT_MT3}
PORT_MT4=${PORT_MT4}
PORT_HTTPS=${PORT_HTTPS}
PORT_STUN=${PORT_STUN}
PORT_RELAY_MIN=${PORT_RELAY_MIN}
PORT_RELAY_MAX=${PORT_RELAY_MAX}
PORT_RTMP=${PORT_RTMP}
PORT_RTMP_HLS=${PORT_RTMP_HLS}
TURN_USER=${TURN_USER}
ENABLE_WEB=${ENABLE_WEB}
WEB_DOMAIN=${WEB_DOMAIN}
WEB_HOST_PORT=${WEB_HOST_PORT}
TELEGRAM_API_ID=${TELEGRAM_API_ID}
ENABLE_BOT=${ENABLE_BOT}
FIXED_VERIFY_CODE=${FIXED_VERIFY_CODE}
COMPOSE_DIR=${COMPOSE_DIR}
EOF
}

configure_firewall() {
  if ! is_yes "${DO_FIREWALL}"; then
    log "Skipping firewall configuration"
    return 0
  fi
  if ! command -v ufw >/dev/null 2>&1; then
    warn "UFW not installed — configure your firewall manually"
    return 0
  fi
  log "Configuring UFW..."
  ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1 || true
  ufw allow "${PORT_MT1},${PORT_MT2},${PORT_MT3},${PORT_MT4}/tcp" comment 'FamilyGram MTProto' >/dev/null 2>&1 || true
  if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
    ufw allow "${PORT_HTTPS}/tcp" comment 'FamilyGram passkey HTTPS' >/dev/null 2>&1 || true
  fi
  ufw allow "${PORT_STUN}/tcp" comment 'FamilyGram STUN/TURN' >/dev/null 2>&1 || true
  ufw allow "${PORT_STUN}/udp" comment 'FamilyGram STUN/TURN' >/dev/null 2>&1 || true
  ufw allow "${PORT_RELAY_MIN}:${PORT_RELAY_MAX}/udp" comment 'FamilyGram TURN relay' >/dev/null 2>&1 || true
  if [[ "${ENABLE_RTMP}" == "yes" ]]; then
    ufw allow "${PORT_RTMP}/tcp" comment 'FamilyGram RTMP' >/dev/null 2>&1 || true
    ufw allow "${PORT_RTMP_HLS}/tcp" comment 'FamilyGram RTMP HLS' >/dev/null 2>&1 || true
  fi
  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    ufw allow "${WEB_HOST_PORT}/tcp" comment 'FamilyGram Web' >/dev/null 2>&1 || true
  fi
  ufw --force enable
}

print_port_forwards() {
  ui_printf '\n%sRouter / firewall — open these ports%s\n' "${C_CYAN}${C_BOLD}" "${C_RESET}"
  ui_printf '%s\n' "Forward WAN → ${LAN_IP} on your router (or allow on cloud firewall):"
  ui_printf '%s\n' "Notation: port(PROTO) — TCP&UDP means create both TCP and UDP rules to the same port."
  hr
  ui_printf '  %-22s %-38s %s\n' "WAN PORT" "SERVICE" "REQUIRED"
  hr
  ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_MT1" TCP)" "MTProto DC1 (main client entry)" "yes"
  ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_MT2" TCP)" "MTProto DC2" "yes"
  ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_MT3" TCP)" "MTProto DC3" "yes"
  ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_MT4" TCP)" "MTProto DC4 (media)" "yes"
  ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_STUN" 'TCP&UDP')" "STUN/TURN (voice/video)" "yes"
  ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "${PORT_RELAY_MIN}-${PORT_RELAY_MAX}" UDP)" "TURN relay media" "yes"
  if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
    ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_HTTPS" TCP)" "Passkey HTTPS gateway (WebAuthn only)" "yes"
  fi
  if [[ "${ENABLE_RTMP}" == "yes" ]]; then
    ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_RTMP" TCP)" "RTMP live streaming" "optional"
    ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$PORT_RTMP_HLS" TCP)" "RTMP HLS playback" "optional"
  fi
  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    ui_printf '  %-22s %-38s %s\n' "$(port_with_proto "$WEB_HOST_PORT" TCP)" "FamilyGram Web (nginx in Docker)" "yes"
  fi
  hr
  ui_printf '%s\n' \
    "Do NOT forward port ${PORT_HTTPS_ALT} — HTTP/WS gateway stays inside Docker (familygram-web → /apiws)."
  ui_printf '\n%sClient build IP:%s %s\n' "${C_BOLD}" "${C_RESET}" "${PUBLIC_IP}"
  ui_printf '%sNever put the LAN IP (%s) in DcOptions — remote clients cannot reach it.%s\n' \
    "${C_YELLOW}" "${LAN_IP}" "${C_RESET}"
  if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
    ui_printf '\n%sPasskey setup:%s\n' "${C_BOLD}" "${C_RESET}"
    ui_printf '%s\n' \
      "  • DNS A: ${PASSKEY_DOMAIN} → ${PUBLIC_IP} (grey cloud / DNS only)" \
      "  • Proxy ${PASSKEY_DOMAIN}:443 → ${LAN_IP}:${PORT_HTTPS}"
  fi
  if [[ "${ENABLE_WEB}" == "yes" && -n "${WEB_DOMAIN}" ]]; then
    ui_printf '\n%sWeb client (FamilyGram):%s\n' "${C_BOLD}" "${C_RESET}"
    ui_printf '%s\n' \
      "  • DNS A: ${WEB_DOMAIN} → ${PUBLIC_IP}" \
      "  • Reverse proxy ${WEB_DOMAIN}:443 → ${LAN_IP}:${WEB_HOST_PORT} (WebSockets ON)" \
      "  • Open https://${WEB_DOMAIN}/ after the stack is up"
  fi
  ui_printf '\n%sGHCR:%s github.com/CyberoniOntoni/FamilyGram-Server/packages must be public, or run docker login ghcr.io\n' \
    "${C_BOLD}" "${C_RESET}"
}

print_config_review() {
  hr
  ui_printf '  %-22s %s\n' "Install directory:" "${INSTALL_DIR}"
  ui_printf '  %-22s %s\n' "Compose directory:" "${COMPOSE_DIR}"
  ui_printf '  %-22s %s\n' "Git branch:" "${REPO_BRANCH}"
  ui_printf '  %-22s %s\n' "Public WAN IP:" "${PUBLIC_IP}"
  ui_printf '  %-22s %s\n' "LAN / host IP:" "${LAN_IP}"
  ui_printf '  %-22s %s\n' "Brand:" "${BRAND}"
  ui_printf '  %-22s %s\n' "Passkey:" "${ENABLE_PASSKEY} (${PASSKEY_DOMAIN})"
  ui_printf '  %-22s %s\n' "MTProto:" \
    "$(port_with_proto "$PORT_MT1" TCP), $(port_with_proto "$PORT_MT2" TCP), $(port_with_proto "$PORT_MT3" TCP), $(port_with_proto "$PORT_MT4" TCP)"
  if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
    ui_printf '  %-22s %s\n' "Passkey HTTPS:" "$(port_with_proto "$PORT_HTTPS" TCP) (host-published)"
  else
    ui_printf '  %-22s %s\n' "Passkey HTTPS:" "disabled (30443/30444 internal only)"
  fi
  ui_printf '  %-22s %s\n' "STUN/TURN:" \
    "$(port_with_proto "$PORT_STUN" 'TCP&UDP'), relay $(port_with_proto "${PORT_RELAY_MIN}-${PORT_RELAY_MAX}" UDP)"
  if [[ "${ENABLE_RTMP}" == "yes" ]]; then
    ui_printf '  %-22s %s\n' "RTMP:" \
      "$(port_with_proto "$PORT_RTMP" TCP) / HLS $(port_with_proto "$PORT_RTMP_HLS" TCP)"
  fi
  ui_printf '  %-22s %s\n' "Install Docker:" "${INSTALL_DOCKER}"
  ui_printf '  %-22s %s\n' "Configure UFW:" "${DO_FIREWALL}"
  if [[ "${ENABLE_BOT:-yes}" == "yes" ]]; then
    ui_printf '  %-22s %s\n' "Login codes:" "@BotFather bot (${BOT_TOKEN:0:12}...)"
  else
    ui_printf '  %-22s %s\n' "Login codes:" "Fixed code (${FIXED_VERIFY_CODE})"
  fi
  ui_printf '  %-22s %s\n' "Web client:" "${ENABLE_WEB} (${WEB_DOMAIN:-n/a})"
  ui_printf '  %-22s %s\n' "API id:" "${TELEGRAM_API_ID}"
  hr
}

compose_profile_list() {
  local profiles=()
  [[ "${ENABLE_BOT}" == "yes" ]] && profiles+=(bot)
  [[ "${ENABLE_WEB}" == "yes" ]] && profiles+=(web)
  if ((${#profiles[@]} > 0)); then
    local IFS=,
    printf '%s' "${profiles[*]}"
  fi
}

compose_with_profiles() {
  local profiles
  profiles="$(compose_profile_list)"
  if [[ -n "${profiles}" ]]; then
    COMPOSE_PROFILES="${profiles}" docker compose "$@"
  else
    docker compose "$@"
  fi
}

compose_hint() {
  local profiles
  profiles="$(compose_profile_list)"
  if [[ -n "${profiles}" ]]; then
    printf 'COMPOSE_PROFILES=%s docker compose' "${profiles}"
  else
    printf 'docker compose'
  fi
}

validate_required_env() {
  local env_file="${COMPOSE_DIR}/.env"
  local -a missing=()
  local key val

  [[ -f "${env_file}" ]] || die "Missing ${env_file}"

  require_env_nonempty() {
    local k="$1"
    val="$(grep -E "^${k}=" "${env_file}" | tail -1 | cut -d= -f2- || true)"
    if [[ -z "${val}" ]]; then
      missing+=("${k}")
    fi
  }

  require_env_nonempty RabbitMQ__Connections__Default__Password
  require_env_nonempty Minio__SecretKey
  require_env_nonempty Minio__BucketName
  require_env_nonempty App__AccessHashSecretKey
  require_env_nonempty App__EncryptionConfig__MessageKeys__0__Key
  require_env_nonempty App__EncryptionConfig__IndexKeys__0__Key
  require_env_nonempty App__DcOptions__0__IpAddress
  require_env_nonempty App__WebRtcConnections__0__Ip
  require_env_nonempty App__WebRtcConnections__0__Password
  require_env_nonempty App__Servers__0__Enabled
  require_env_nonempty COTURN_EXTERNAL_IP

  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    require_env_nonempty TELEGRAM_API_ID
    require_env_nonempty TELEGRAM_API_HASH
    require_env_nonempty WEB_DOMAIN
    require_env_nonempty WEB_BASE_URL
  fi

  if [[ "${ENABLE_BOT}" == "yes" ]]; then
    require_env_nonempty BOT_TOKEN
  else
    require_env_nonempty App__FixedVerifyCode
  fi

  if ((${#missing[@]} > 0)); then
    die "Installer .env is missing required values: ${missing[*]}"
  fi

  log "Required .env parameters present ($(wc -l < "${env_file}") lines)"
}

validate_compose_stack() {
  [[ -f "${COMPOSE_FILE}" ]] || die "Missing ${COMPOSE_FILE} — clone or install dir wrong?"
  [[ -f "${COMPOSE_DIR}/.env.example" ]] || die "Missing ${COMPOSE_DIR}/.env.example"
  validate_required_env
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Validating docker compose configuration..."
    compose_with_profiles config -q >/dev/null \
      || die "docker compose config failed — check ${COMPOSE_DIR}/.env and compose files"
  else
    warn "Docker not available — skipped compose config validation"
  fi
}

start_stack() {
  log "Pulling server Docker images (first run may take several minutes)..."
  compose_with_profiles pull --ignore-buildable

  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    log "Building FamilyGram Web image (npm build — may take several minutes)..."
    compose_with_profiles build familygram-web
  fi

  log "Starting FamilyGram stack (profiles: $(compose_profile_list || echo default))..."
  if [[ "${ENABLE_BOT}" != "yes" ]]; then
    log "Using fixed login code — verification bot skipped"
  fi
  compose_with_profiles up -d

  log "Waiting for gateway-server (up to 120s)..."
  local i
  for i in $(seq 1 24); do
    if compose_with_profiles logs gateway-server 2>/dev/null | grep -q "${PORT_MT1}"; then
      log "Gateway is listening on port ${PORT_MT1}"
      return 0
    fi
    sleep 5
  done
  warn "Gateway did not log port ${PORT_MT1} yet — check: $(compose_hint) logs gateway-server"
}

prompt_api_credentials() {
  if [[ -n "${TELEGRAM_API_ID}" && -n "${TELEGRAM_API_HASH}" ]]; then
    log "Telegram API credentials provided via environment/flags"
    return 0
  fi
  ui_printf '%s\n' \
    "Register an app at https://my.telegram.org and copy api_id + api_hash." \
    "The web client is built with these values — they must stay in sync." \
    ""
  while true; do
    read_with_prompt TELEGRAM_API_ID "  Telegram API id (number): "
    if [[ "$TELEGRAM_API_ID" =~ ^[0-9]+$ ]]; then
      break
    fi
    warn "API id should be numeric"
  done
  while true; do
    read_with_prompt TELEGRAM_API_HASH "  Telegram API hash: "
    if [[ -n "$TELEGRAM_API_HASH" ]]; then
      break
    fi
    warn "API hash cannot be empty"
  done
}

prompt_bot_token() {
  if [[ -n "${BOT_TOKEN}" ]]; then
    log "BOT_TOKEN provided via environment/flag"
    return 0
  fi
  while true; do
    read_with_prompt BOT_TOKEN "  Bot token from @BotFather: "
    if [[ "$BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
      break
    fi
    warn "Token should look like 123456789:AAH..."
  done
}

prompt_login_verification() {
  if [[ -n "${FIXED_VERIFY_CODE}" ]]; then
    is_verify_code "${FIXED_VERIFY_CODE}" || die "Invalid FIXED_VERIFY_CODE: use 4-8 digits"
    ENABLE_BOT="no"
    BOT_TOKEN=""
    log "Using fixed verify code from environment/flag — @BotFather bot skipped"
    return 0
  fi
  if [[ -n "${BOT_TOKEN}" ]]; then
    ENABLE_BOT="yes"
    FIXED_VERIFY_CODE=""
    log "BOT_TOKEN provided via environment/flag"
    return 0
  fi

  ui_printf '%s\n' \
    "Login verification — choose ONE:" \
    "  • @BotFather bot — sends a unique code to each user (shared / production setups)" \
    "  • Fixed code — every user enters the same code (private or lab setups)" \
    ""
  prompt_yes_no USE_FIXED_VERIFY_CODE "Use a fixed login code for all users?" "no"
  if [[ "${USE_FIXED_VERIFY_CODE}" == "yes" ]]; then
    ENABLE_BOT="no"
    BOT_TOKEN=""
    while true; do
      read_with_prompt FIXED_VERIFY_CODE "  Fixed login code (4-8 digits): "
      if is_verify_code "${FIXED_VERIFY_CODE}"; then
        break
      fi
      warn "Enter 4-8 digits only"
    done
    log "Fixed login code set — @BotFather bot will not be configured"
  else
    ENABLE_BOT="yes"
    FIXED_VERIFY_CODE=""
    prompt_bot_token
  fi
}

run_install_wizard() {
  local total_steps=8

  banner
  ui_printf '  %sInstaller v%s%s\n\n' "${C_DIM}" "${INSTALLER_VERSION}" "${C_RESET}"

  step 1 "$total_steps" "Before you start"
  ui_printf '%s\n' \
    "You will need:" \
    "  • Public WAN IP (what clients connect to)" \
    "  • LAN IP of this machine (for router port forwards)" \
    "  • Login verification: @BotFather bot token OR a fixed login code" \
    "  • Telegram API id + hash from my.telegram.org (web client)" \
    "  • Public web hostname (e.g. web.example.com) if using the web UI" \
    "  • Node.js 22+ on the host when web is enabled (installer upgrades v20 via nvm)" \
    ""
  ui_printf '%sRules:%s MTProto must go direct to your IP — not through Cloudflare proxy or NPM.\n\n' \
    "${C_YELLOW}" "${C_RESET}"

  check_lxc_prereqs

  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    log "OS: ${PRETTY_NAME:-unknown}"
  fi

  if ! confirm "Start the interactive installer?"; then
    ui_printf '\nAborted.\n'
    exit 0
  fi

  step 2 "$total_steps" "Where to install"
  prompt INSTALL_DIR "Install directory" "${INSTALL_DIR}"
  COMPOSE_DIR="${INSTALL_DIR}/docker/compose"
  COMPOSE_FILE="${COMPOSE_DIR}/docker-compose.yml"

  step 3 "$total_steps" "Network & branding"
  ui_printf '%s\n' \
    "Public IP goes into client configs. LAN IP is only for port-forward targets." \
    ""
  local detected_lan="" detected_public=""
  log "Detecting network addresses..."
  detected_lan="$(detect_lan_ip 2>/dev/null || true)"
  detected_public="$(detect_public_ip 2>/dev/null || true)"
  show_detected_ips "$detected_lan" "$detected_public"
  prompt PUBLIC_IP "Public WAN IP" "" is_ipv4
  prompt LAN_IP "LAN IP of this host" "" is_ipv4
  prompt BRAND "Brand / app name" "FamilyGram"
  prompt_yes_no ENABLE_WEB "Deploy FamilyGram Web client in Docker?" "yes"
  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    prompt WEB_DOMAIN "Public web hostname (e.g. web.example.com)" "" is_domain
    prompt WEB_HOST_PORT "Web UI host port (nginx in Docker)" "$WEB_HOST_PORT" is_port
  fi
  prompt_yes_no ENABLE_PASSKEY "Enable passkey (WebAuthn)? Needs HTTPS + domain" "no"
  if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
    prompt PASSKEY_DOMAIN "Passkey domain (e.g. tg.example.com)" "" is_domain
  else
    PASSKEY_DOMAIN="${PASSKEY_DOMAIN:-localhost}"
  fi

  step 4 "$total_steps" "Ports"
  ui_printf '%s\n' "Port notation: number(PROTO) — TCP, UDP, or TCP&UDP (both protocols on same port)."
  prompt_yes_no CUSTOMIZE_PORTS "Customize service ports? (No = use FamilyGram Server defaults)" "no"
  if [[ "${CUSTOMIZE_PORTS}" == "yes" ]]; then
    prompt PORT_MT1 "MTProto DC1 (main) — TCP only" "$PORT_MT1" is_port
    prompt PORT_MT2 "MTProto DC2 — TCP only" "$PORT_MT2" is_port
    prompt PORT_MT3 "MTProto DC3 — TCP only" "$PORT_MT3" is_port
    prompt PORT_MT4 "MTProto DC4 (media) — TCP only" "$PORT_MT4" is_port
    if [[ "${ENABLE_PASSKEY}" == "yes" ]]; then
      prompt PORT_HTTPS "Passkey HTTPS gateway — TCP only (host-published)" "$PORT_HTTPS" is_port
    fi
    prompt PORT_STUN "STUN/TURN — TCP&UDP (forward both)" "$PORT_STUN" is_port
    prompt PORT_RELAY_MIN "TURN relay range start — UDP only" "$PORT_RELAY_MIN" is_port
    prompt PORT_RELAY_MAX "TURN relay range end — UDP only" "$PORT_RELAY_MAX" is_port
    if (( PORT_RELAY_MIN >= PORT_RELAY_MAX )); then
      die "Relay range invalid: ${PORT_RELAY_MIN} must be < ${PORT_RELAY_MAX}"
    fi
  else
    log "Default ports: $(port_with_proto 20443 TCP),$(port_with_proto 20543 TCP),$(port_with_proto 20643 TCP),$(port_with_proto 20644 TCP); $(port_with_proto 5348 'TCP&UDP'); relay $(port_with_proto 49152-49172 UDP)"
  fi

  prompt_yes_no ENABLE_RTMP "Expose RTMP live streaming ports?" "no"
  if [[ "${ENABLE_RTMP}" == "yes" ]]; then
    prompt PORT_RTMP "RTMP port — TCP only" "$PORT_RTMP" is_port
    prompt PORT_RTMP_HLS "RTMP HLS port — TCP only" "$PORT_RTMP_HLS" is_port
  fi

  step 5 "$total_steps" "API credentials & login"
  if [[ "${ENABLE_WEB}" == "yes" ]]; then
    prompt_api_credentials
  else
    TELEGRAM_API_ID="${TELEGRAM_API_ID:-0}"
    TELEGRAM_API_HASH="${TELEGRAM_API_HASH:-disabled}"
  fi
  prompt_login_verification

  step 6 "$total_steps" "Docker options"
  TURN_PASS="${TURN_PASS:-$(openssl rand -hex 16)}"
  log "Generated TURN password"

  if command -v docker >/dev/null 2>&1; then
    INSTALL_DOCKER="no"
    log "Docker already installed"
  else
    prompt_yes_no INSTALL_DOCKER "Install Docker via get.docker.com?" "yes"
  fi
  if is_yes "${DO_FIREWALL}"; then
    prompt_yes_no DO_FIREWALL "Configure UFW firewall on this host?" "yes"
  fi

  step 7 "$total_steps" "Review"
  print_config_review
  if ! confirm "Apply configuration and install?"; then
    ui_printf '\nAborted. No changes made.\n'
    exit 0
  fi

  step 8 "$total_steps" "Installing"
}

run_install_apply() {
  install_prerequisites
  clone_or_update_repo

  cd "${COMPOSE_DIR}"
  write_env_file
  patch_compose "${COMPOSE_FILE}"
  write_compose_override
  prepare_data_dirs
  validate_compose_stack
  save_install_summary
  configure_firewall
  print_port_forwards

  if [[ "${DO_START}" == true ]]; then
    start_stack
    compose_with_profiles ps
  elif [[ "${NON_INTERACTIVE}" != true ]]; then
    ui_printf '\n'
    if confirm "Start docker compose now?"; then
      start_stack
      compose_with_profiles ps
    else
      log "Stack not started. When ready:"
      ui_printf '    cd %s && %s up -d\n' "${COMPOSE_DIR}" "$(compose_hint)"
    fi
  fi

  ui_printf '\n%sDone — FamilyGram stack is ready%s\n\n' "${C_GREEN}${C_BOLD}" "${C_RESET}"
  ui_printf '  .env:      %s/.env\n' "${COMPOSE_DIR}"
  ui_printf '  Summary:   %s\n' "${SUMMARY_FILE}"
  ui_printf '  Logs:      cd %s && %s logs -f\n' "${COMPOSE_DIR}" "$(compose_hint)"
  if [[ "${ENABLE_WEB}" == "yes" && -n "${WEB_DOMAIN}" ]]; then
    ui_printf '  Web UI:    https://%s/ (after reverse proxy is configured)\n' "${WEB_DOMAIN}"
    ui_printf '  Local:     http://%s:%s/\n' "${LAN_IP}" "${WEB_HOST_PORT}"
  fi
  if [[ "${ENABLE_BOT}" == "yes" ]]; then
    ui_printf '  Next:      port-forward table above, link phone in @BotFather bot, native clients use IP %s\n\n' "${PUBLIC_IP}"
  else
    ui_printf '  Next:      port-forward table above, sign in with phone + fixed code %s, native clients use IP %s\n\n' \
      "${FIXED_VERIFY_CODE}" "${PUBLIC_IP}"
  fi
}