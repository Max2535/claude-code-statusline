# claude-code-statusline

> Status line dashboard for [Claude Code](https://claude.ai/code) — mimics the **Plan Usage Limits** popup from claude.ai

![Claude Code v2.1+](https://img.shields.io/badge/Claude_Code-v2.1%2B-orange)
![Python 3.6+](https://img.shields.io/badge/Python-3.6%2B-blue)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows%20Git%20Bash-lightgrey)

## Preview

```
  Plan usage limits  Max (5x)  ──────────────────────────────────────────────────────────────
  Current session        █░░░░░░░░░░░░░░░░░░░░░░░░░░░░   5.0% used      Resets in ~3 hr 53 min
  Weekly · All models    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   0.0% used      Resets Tue 3:59 AM  (~3d 0h)
  Context window         ██░░░░░░░░░░░░░░░░░░░░░░░░░░░   5%  51.2k / 1.0M  out:3.2k  cache:21.2k
  [CAVEMAN]  │  [Opus 4.8 (1M context)]  │  🌿 main +2 ~5  │  $1.2543  │  ⏱ 3m53s  api:18s  │  +342-87  │  ⚡ high  │  💭 thinking  │  v2.1.175
```

Progress bar colors: 🔵 normal → 🟡 70%+ → 🔴 90%+

---

## Requirements

| Requirement | Version |
|-------------|---------|
| Claude Code | v2.1+ |
| Python      | 3.6+   |
| Plan        | Max or Pro (for rate limit display) |

---

## Install

### Option 1 — One-liner (curl)

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Max2535/claude-code-statusline/main/install.sh)
```

### Option 2 — Git clone

```bash
git clone https://github.com/Max2535/claude-code-statusline.git
cd claude-code-statusline
bash install.sh
```

### Windows (Git Bash)

Same commands as above — run inside **Git Bash** (not PowerShell or CMD).

---

## Test after install

```bash
cat ~/.claude/statusline-test.json | python ~/.claude/statusline.py
```

Then restart Claude Code. The status line appears at the bottom of the interface.

---

## What's displayed

| Line | Content | Source field |
|------|---------|-------------|
| **1** | `Plan usage limits  Max (5x)` header | — |
| **2** | Current session progress bar + % + reset countdown | `rate_limits.five_hour` |
| **3** | Weekly all-models progress bar + % + reset day/time | `rate_limits.seven_day` |
| **4** | Context window bar + tokens in/out + cache hits | `context_window` |
| **5** | Agent · Model · Git branch · Cost · Duration · Lines · Effort · Thinking | `cost`, `model`, etc. |

> **Note:** "Sonnet only" weekly limit, daily routine runs, and usage credits balance  
> are **not available** via the Claude Code status line API.

---

## Uninstall

```bash
bash <(curl -sSL https://raw.githubusercontent.com/Max2535/claude-code-statusline/main/uninstall.sh)
```

Or from cloned directory:

```bash
bash uninstall.sh
```

---

## Manual settings.json (optional)

The installer writes this automatically, but you can also set it manually in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "python ~/.claude/statusline.py",
    "refreshInterval": 15
  }
}
```

Use `python3` if that's your system default.

---

## Troubleshooting

**Status line not appearing**
- Run the test command above to verify the script works
- Check `~/.claude/settings.json` contains `statusLine` config
- Restart Claude Code after any settings change

**`python: command not found`**
- Change `python` to `python3` in `settings.json`

**ANSI colors show as literal codes**
- Your terminal may not support ANSI — most modern terminals (Windows Terminal, iTerm2, etc.) do

**Timestamps show as past/wrong time**
- The `resets_at` field is only populated after your first API call in the session — it appears blank on fresh start

---

## License

MIT — see [LICENSE](LICENSE)
