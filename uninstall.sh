#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# Claude Code Status Line Dashboard — Uninstaller
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

INSTALL_DIR="${HOME}/.claude"
SCRIPT_PATH="${INSTALL_DIR}/statusline.py"
SETTINGS_PATH="${INSTALL_DIR}/settings.json"

R="\033[0m"; BOLD="\033[1m"
GREEN="\033[32m"; CYAN="\033[36m"; YELLOW="\033[33m"; RED="\033[31m"; DIM="\033[2m"

ok()   { echo -e "  ${GREEN}✓${R}  $*"; }
info() { echo -e "  ${CYAN}→${R}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${R}  $*"; }
err()  { echo -e "  ${RED}✗ ERROR:${R}  $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}${CYAN}Claude Code Status Line Dashboard — Uninstaller${R}"
echo -e "${DIM}────────────────────────────────────────────────${R}"
echo ""

# ── Remove statusline.py ──────────────────────────────────────────
if [[ -f "$SCRIPT_PATH" ]]; then
    rm "$SCRIPT_PATH"
    ok "Removed ${SCRIPT_PATH}"
else
    warn "Script not found: ${SCRIPT_PATH}"
fi

# ── Remove test data ──────────────────────────────────────────────
TEST_PATH="${INSTALL_DIR}/statusline-test.json"
[[ -f "$TEST_PATH" ]] && rm "$TEST_PATH" && ok "Removed ${TEST_PATH}"

# ── Remove statusLine from settings.json ─────────────────────────
if [[ -f "$SETTINGS_PATH" ]]; then
    # Detect Python
    PYTHON=""
    for cmd in python3 python; do
        if command -v "$cmd" &>/dev/null; then
            VER=$("$cmd" -c "import sys; print(sys.version_info >= (3,6))" 2>/dev/null || echo "False")
            [ "$VER" = "True" ] && PYTHON="$cmd" && break
        fi
    done

    if [[ -n "$PYTHON" ]]; then
        cp "$SETTINGS_PATH" "${SETTINGS_PATH}.uninstall.bak"
        info "Backup → ${SETTINGS_PATH}.uninstall.bak"

        "$PYTHON" - "$SETTINGS_PATH" << 'PYEOF'
import json, os, sys
path = sys.argv[1]
try:
    with open(path, "r", encoding="utf-8-sig") as f:
        settings = json.load(f)
    removed = settings.pop("statusLine", None)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
    if removed:
        print("    statusLine key removed from settings.json")
    else:
        print("    statusLine key was not present")
except Exception as e:
    print(f"    Warning: {e}")
PYEOF
        ok "settings.json updated"
    else
        warn "Python not found — manually remove 'statusLine' from ${SETTINGS_PATH}"
    fi
else
    warn "settings.json not found: ${SETTINGS_PATH}"
fi

# ── Clean git cache files ─────────────────────────────────────────
CLEANED=0
for f in /tmp/cc-sl-git-*; do
    [[ -f "$f" ]] && rm "$f" && (( CLEANED++ )) || true
done
[[ $CLEANED -gt 0 ]] && ok "Cleaned ${CLEANED} git cache file(s)"

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}${BOLD}Uninstalled successfully${R}"
echo -e "  ${YELLOW}Restart Claude Code to apply changes${R}"
echo ""
