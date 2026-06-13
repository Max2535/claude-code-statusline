#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Claude Code Status Line Dashboard — Installer
#
# Usage (git clone):
#   git clone https://github.com/Max2535/claude-code-statusline
#   cd claude-code-statusline && bash install.sh
#
# Usage (one-liner):
#   bash <(curl -sSL https://raw.githubusercontent.com/Max2535/claude-code-statusline/main/install.sh)
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Configurable ──────────────────────────────────────────────────
REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/Max2535/claude-code-statusline/main}"
SCRIPT_NAME="statusline.py"
REFRESH_INTERVAL=15

# ── Paths ─────────────────────────────────────────────────────────
INSTALL_DIR="${HOME}/.claude"
SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
SETTINGS_PATH="${INSTALL_DIR}/settings.json"

# ── Colors ────────────────────────────────────────────────────────
R="\033[0m"
BOLD="\033[1m"
GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; RED="\033[31m"; DIM="\033[2m"

ok()    { echo -e "  ${GREEN}✓${R}  $*"; }
info()  { echo -e "  ${CYAN}→${R}  $*"; }
warn()  { echo -e "  ${YELLOW}⚠${R}  $*"; }
err()   { echo -e "  ${RED}✗ ERROR:${R}  $*" >&2; exit 1; }
header(){ echo -e "\n${BOLD}${CYAN}$*${R}"; echo -e "${DIM}$(printf '─%.0s' $(seq 1 ${#1}))${R}"; }

# ══════════════════════════════════════════════════════════════════
header "Claude Code Status Line Dashboard — Installer"
echo ""
# ══════════════════════════════════════════════════════════════════

# ── 1. Detect Python 3.6+ ─────────────────────────────────────────
info "Detecting Python..."
PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null 2>&1; then
        VER=$("$cmd" -c "import sys; print(sys.version_info >= (3,6))" 2>/dev/null || echo "False")
        if [ "$VER" = "True" ]; then
            PYTHON="$cmd"
            PY_VER=$("$cmd" --version 2>&1)
            ok "Python: $PYTHON  ($PY_VER)"
            break
        fi
    fi
done
[ -z "$PYTHON" ] && err "Python 3.6+ not found. Install from https://python.org"

# ── 2. Create ~/.claude ───────────────────────────────────────────
mkdir -p "$INSTALL_DIR"
ok "Install dir: ${INSTALL_DIR}"

# ── 3. Copy (local) or Download (remote) statusline.py ───────────
info "Installing ${SCRIPT_NAME}..."

# Detect local repo (not piped via curl)
_SRC="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -n "$_SRC" && "$_SRC" != "bash" && "$_SRC" != "/dev/stdin" && -f "$_SRC" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$_SRC")" && pwd)"
fi

LOCAL_PY="${SCRIPT_DIR}/${SCRIPT_NAME}"

if [[ -n "$SCRIPT_DIR" && -f "$LOCAL_PY" ]]; then
    cp "$LOCAL_PY" "$SCRIPT_PATH"
    ok "Copied from local repo → ${SCRIPT_PATH}"
else
    # Download from GitHub
    DOWNLOAD_URL="${REPO_RAW}/${SCRIPT_NAME}"
    info "Downloading from ${DOWNLOAD_URL}"

    if command -v curl &>/dev/null; then
        curl -sSfL "$DOWNLOAD_URL" -o "$SCRIPT_PATH" \
            || err "Download failed. Check REPO_RAW URL or internet connection."
    elif command -v wget &>/dev/null; then
        wget -qO "$SCRIPT_PATH" "$DOWNLOAD_URL" \
            || err "Download failed. wget error."
    else
        err "curl or wget required for remote install"
    fi
    ok "Downloaded → ${SCRIPT_PATH}"
fi

chmod +x "$SCRIPT_PATH" 2>/dev/null || true

# ── 4. Merge statusLine into settings.json ────────────────────────
info "Updating settings.json..."

# Backup
if [[ -f "$SETTINGS_PATH" ]]; then
    cp "$SETTINGS_PATH" "${SETTINGS_PATH}.bak"
    ok "Backup → ${SETTINGS_PATH}.bak"
fi

# Use a temp Python script to merge JSON safely
_TMPPY=$(mktemp /tmp/cc_sl_install_XXXXX.py)
trap "rm -f $_TMPPY" EXIT

cat > "$_TMPPY" << PYEOF
import json, os, sys

python_cmd    = sys.argv[1]
settings_path = sys.argv[2]
refresh       = int(sys.argv[3])

# Load existing or init
settings = {}
if os.path.exists(settings_path):
    try:
        with open(settings_path, "r", encoding="utf-8-sig") as f:
            settings = json.load(f)
    except Exception as e:
        print(f"    Warning: existing settings.json unreadable ({e}), creating fresh copy")

# Build command — use ~/.claude/statusline.py (cross-platform ~)
settings["statusLine"] = {
    "type": "command",
    "command": f"{python_cmd} ~/.claude/statusline.py",
    "refreshInterval": refresh
}

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)

print(f"    command: {python_cmd} ~/.claude/statusline.py")
print(f"    refreshInterval: {refresh}s")
PYEOF

"$PYTHON" "$_TMPPY" "$PYTHON" "$SETTINGS_PATH" "$REFRESH_INTERVAL"
ok "settings.json updated"

# ── 5. Write test data ────────────────────────────────────────────
TEST_PATH="${INSTALL_DIR}/statusline-test.json"

# Compute realistic reset timestamps
FH_RESET=$("$PYTHON" -c "import time; print(int(time.time()) + 14100)")  # ~3h 55m
WD_RESET=$("$PYTHON" -c "import time; print(int(time.time()) + 259200)")  # ~3d

cat > "$TEST_PATH" << TESTEOF
{
  "model": { "id": "claude-opus-4-8", "display_name": "Opus 4.8 (1M context)" },
  "agent": { "name": "CAVEMAN" },
  "workspace": {
    "current_dir": "C:/Projects/restaurant-system",
    "repo": { "host": "github.com", "owner": "max", "name": "restaurant-system" }
  },
  "context_window": {
    "used_percentage": 5,
    "context_window_size": 1000000,
    "total_input_tokens": 51200,
    "total_output_tokens": 3200,
    "current_usage": {
      "input_tokens": 20000,
      "output_tokens": 3200,
      "cache_creation_input_tokens": 10000,
      "cache_read_input_tokens": 21200
    }
  },
  "cost": {
    "total_cost_usd": 1.2543,
    "total_duration_ms": 233400,
    "total_api_duration_ms": 18300,
    "total_lines_added": 342,
    "total_lines_removed": 87
  },
  "rate_limits": {
    "five_hour":  { "used_percentage": 5.0, "resets_at": ${FH_RESET} },
    "seven_day":  { "used_percentage": 0.0, "resets_at": ${WD_RESET} }
  },
  "effort":   { "level": "high" },
  "thinking": { "enabled": true },
  "session_id":   "demo-abc12345",
  "session_name": "restaurant-dev",
  "version":      "2.1.175"
}
TESTEOF
ok "Test data → ${TEST_PATH}"

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}╔═══════════════════════════════════════════════════╗${R}"
echo -e "  ${GREEN}${BOLD}║  ✓  Status Line Dashboard installed!              ║${R}"
echo -e "  ${GREEN}${BOLD}╚═══════════════════════════════════════════════════╝${R}"
echo ""
echo -e "  ${DIM}Script  :${R}  ${CYAN}${SCRIPT_PATH}${R}"
echo -e "  ${DIM}Settings:${R}  ${CYAN}${SETTINGS_PATH}${R}"
echo ""
echo -e "  ${BOLD}Test now:${R}"
echo -e "  ${CYAN}cat ~/.claude/statusline-test.json | $PYTHON ~/.claude/statusline.py${R}"
echo ""
echo -e "  ${YELLOW}Restart Claude Code to activate the status line${R}"
echo ""
