#!/usr/bin/env python3
"""
Claude Code Status Line — Plan Usage Limits Dashboard
Mimics the Claude.ai Plan Usage Limits popup

Project : https://github.com/Max2535/claude-code-statusline
Install : bash <(curl -sSL https://raw.githubusercontent.com/Max2535/claude-code-statusline/main/install.sh)
"""
import json, sys, os, time, datetime, re, subprocess, pathlib, tempfile

data = json.load(sys.stdin)

# ── ANSI ──────────────────────────────────────────────────────────
R = "\033[0m"
def _a(c, t): return f"\033[{c}m{t}{R}"
def bold(t):    return _a("1",  t)
def dim(t):     return _a("2",  t)
def red(t):     return _a("31", t)
def green(t):   return _a("32", t)
def yellow(t):  return _a("33", t)
def blue(t):    return _a("34", t)
def cyan(t):    return _a("36", t)

_AX = re.compile(r"\033\[[^m]*m")
def vlen(s):   return len(_AX.sub("", s))
def pad(s, w): return s + " " * max(0, w - vlen(s))

def safe(d, *keys, default=None):
    for k in keys:
        if not isinstance(d, dict): return default
        d = d.get(k)
        if d is None: return default
    return d

# ── Extract fields ────────────────────────────────────────────────
model    = safe(data, "model", "display_name") or "unknown"
agent    = safe(data, "agent", "name")         or ""
cwd      = safe(data, "workspace", "current_dir") or data.get("cwd", "")
folder   = os.path.basename(cwd.replace("\\", "/")) or cwd

repo_own = safe(data, "workspace", "repo", "owner") or ""
repo_nm  = safe(data, "workspace", "repo", "name")  or ""
git_wt   = safe(data, "workspace", "git_worktree")  or ""

ctx      = data.get("context_window") or {}
ctx_pct  = float(ctx.get("used_percentage")  or 0)
ctx_sz   = ctx.get("context_window_size")    or 200_000
in_tok   = ctx.get("total_input_tokens")     or 0
out_tok  = ctx.get("total_output_tokens")    or 0
cache_r  = safe(data, "context_window", "current_usage", "cache_read_input_tokens") or 0
over200k = data.get("exceeds_200k_tokens")   or False

cost_d   = data.get("cost") or {}
cost_usd = cost_d.get("total_cost_usd")       or 0
dur_ms   = cost_d.get("total_duration_ms")    or 0
api_ms   = cost_d.get("total_api_duration_ms") or 0
l_add    = cost_d.get("total_lines_added")    or 0
l_rm     = cost_d.get("total_lines_removed")  or 0

rl       = data.get("rate_limits") or {}
fh       = rl.get("five_hour")  or {}
wd_rl    = rl.get("seven_day")  or {}
fh_pct   = fh.get("used_percentage")
wd_pct   = wd_rl.get("used_percentage")
fh_at    = fh.get("resets_at")
wd_at    = wd_rl.get("resets_at")

thinking  = safe(data, "thinking", "enabled") or False
effort    = safe(data, "effort",   "level")   or ""
vim_mode  = safe(data, "vim",      "mode")    or ""
pr        = data.get("pr") or {}
pr_num    = pr.get("number")
pr_state  = pr.get("review_state") or ""
sess_id   = (data.get("session_id") or "")[:8]
sess_name = data.get("session_name") or ""
version   = data.get("version") or ""
cols      = int(os.environ.get("COLUMNS", 120))

# ── Git status (cached 5 s by session_id to avoid lag) ───────────
branch = ""; staged = modified = untracked = 0
_tmp   = pathlib.Path(tempfile.gettempdir()) / f"cc-sl-git-{sess_id}"
TTL    = 5

def _load_cache():
    try:
        if _tmp.exists() and (time.time() - _tmp.stat().st_mtime) < TTL:
            p = _tmp.read_text().strip().split("|")
            if len(p) == 4:
                return p[0], int(p[1]), int(p[2]), int(p[3])
    except Exception:
        pass
    return None

def _save_cache(br, st, mo, un):
    try: _tmp.write_text(f"{br}|{st}|{mo}|{un}")
    except Exception: pass

_hit = _load_cache()
if _hit:
    branch, staged, modified, untracked = _hit
else:
    try:
        _run = lambda cmd: subprocess.check_output(
            cmd, text=True, stderr=subprocess.DEVNULL, cwd=cwd).strip()
        _run(["git", "rev-parse", "--git-dir"])
        branch    = _run(["git", "branch", "--show-current"])
        _st       = _run(["git", "diff", "--cached", "--numstat"])
        _mo       = _run(["git", "diff", "--numstat"])
        _un       = _run(["git", "ls-files", "--others", "--exclude-standard"])
        staged    = len([l for l in _st.split("\n") if l])
        modified  = len([l for l in _mo.split("\n") if l])
        untracked = len([l for l in _un.split("\n") if l])
        _save_cache(branch, staged, modified, untracked)
    except Exception:
        _save_cache("", 0, 0, 0)

# ── Helpers ───────────────────────────────────────────────────────
def progress_bar(pct, w=28):
    pct = float(pct or 0)
    f   = max(1 if pct > 0 else 0, int(pct * w / 100))
    e   = w - f
    c   = "\033[31m" if pct >= 90 else "\033[33m" if pct >= 70 else "\033[34m"
    return f"{c}{'█' * f}{R}\033[2m{'░' * e}{R}"

def fmt_countdown(ep):
    """~3 hr 53 min"""
    if not ep: return ""
    d = max(0, int(ep) - int(time.time()))
    if d == 0: return "now"
    h, r = divmod(d, 3600); m = r // 60
    if h >= 24: return f"~{h // 24}d {h % 24}h"
    return f"~{h} hr {m:02d} min"

def fmt_reset_day(ep):
    """Tue 3:59 AM"""
    if not ep: return ""
    dt  = datetime.datetime.fromtimestamp(int(ep))
    day = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][dt.weekday()]
    h12 = dt.hour % 12 or 12
    ap  = "AM" if dt.hour < 12 else "PM"
    return f"{day} {h12}:{dt.minute:02d} {ap}"

def fmt_dur(ms):
    s = (ms or 0) // 1000
    h, r = divmod(s, 3600); m, s = divmod(r, 60)
    return f"{h}h{m}m" if h else f"{m}m{s}s" if m else f"{s}s"

def fmt_tok(n):
    if n >= 1_000_000: return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:     return f"{n / 1_000:.1f}k"
    return str(int(n))

# ── Layout ────────────────────────────────────────────────────────
LABEL_W = 22   # label column visible width
PCT_W   = 14   # "100.0% used" max

def usage_row(label, pct, reset_str):
    p = f"{float(pct or 0):.1f}% used" if pct is not None else "— no data"
    c = yellow if pct is not None else dim
    return (f"  {pad(dim(label), LABEL_W)}  "
            f"{progress_bar(pct)}  "
            f"{pad(c(p), PCT_W)}  "
            f"{dim(reset_str)}")

# ══════════════════════════════════════════════════════════════════
# LINE 1  Plan usage limits  Max (5x) ────────────────────────────
# ══════════════════════════════════════════════════════════════════
plain_hdr = "  Plan usage limits  Max (5x)"
fill_len  = max(2, cols - len(plain_hdr) - 2)
print(f"  {bold('Plan usage limits')}  {cyan('Max (5x)')}  {dim('─' * fill_len)}")

# ══════════════════════════════════════════════════════════════════
# LINE 2  Current session  (5-hour rolling window)
# ══════════════════════════════════════════════════════════════════
fh_reset = f"Resets in {fmt_countdown(fh_at)}" if fh_at else "—"
print(usage_row("Current session", fh_pct, fh_reset))

# ══════════════════════════════════════════════════════════════════
# LINE 3  Weekly · All models  (7-day window)
# ══════════════════════════════════════════════════════════════════
wd_day   = fmt_reset_day(wd_at)
wd_cnt   = fmt_countdown(wd_at)
wd_reset = f"Resets {wd_day}  ({wd_cnt})" if wd_day else "—"
print(usage_row("Weekly · All models", wd_pct, wd_reset))

# ══════════════════════════════════════════════════════════════════
# LINE 4  Context window
# ══════════════════════════════════════════════════════════════════
ctx_detail = (f"{int(ctx_pct)}%  "
              f"{fmt_tok(in_tok)} / {fmt_tok(ctx_sz)}"
              f"  out:{fmt_tok(out_tok)}"
              + (f"  cache:{fmt_tok(cache_r)}" if cache_r else "")
              + (f"  {red('⚠ >200k')}" if over200k else ""))
print(f"  {pad(dim('Context window'), LABEL_W)}  {progress_bar(ctx_pct)}  {dim(ctx_detail)}")

# ══════════════════════════════════════════════════════════════════
# LINE 5  Session info
# ══════════════════════════════════════════════════════════════════
inf = []
if agent:           inf.append(cyan(f"[{agent}]"))
inf.append(f"[{model}]")

if branch:
    gs = green(branch)
    if staged:    gs += f" {green(f'+{staged}')}"
    if modified:  gs += f" {yellow(f'~{modified}')}"
    if untracked: gs += f" {dim(f'?{untracked}')}"
    inf.append(f"🌿 {gs}")
elif folder:
    inf.append(f"📁 {folder}")

if repo_own and repo_nm: inf.append(dim(f"📦 {repo_own}/{repo_nm}"))
if git_wt:               inf.append(f"\033[35m🌲 {git_wt}{R}")

if pr_num:
    pc = {"approved": green, "changes_requested": red, "draft": dim}.get(pr_state, yellow)
    inf.append(f"🔀 PR#{pc(str(pr_num))}{f' [{pr_state}]' if pr_state else ''}")

inf.append(yellow(f"${cost_usd:.4f}"))
inf.append(f"⏱ {fmt_dur(dur_ms)}  api:{fmt_dur(api_ms)}")
if l_add or l_rm: inf.append(f"{green(f'+{l_add}')}{red(f'-{l_rm}')}")

if effort:
    ec = {"xhigh": red, "max": red, "high": yellow, "medium": green}.get(effort, dim)
    inf.append(f"⚡ {ec(effort)}")
if thinking:  inf.append(cyan("💭 thinking"))
if vim_mode:  inf.append(dim(f"vim:{vim_mode}"))
if sess_name: inf.append(cyan(f"📌 {sess_name}"))
elif sess_id: inf.append(dim(f"#{sess_id}"))
if version:   inf.append(dim(f"v{version}"))

print("  " + "  │  ".join(inf))
