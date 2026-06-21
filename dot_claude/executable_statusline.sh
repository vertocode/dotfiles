#!/bin/bash
set -f

input=$(cat)
[ -z "$input" ] && printf "Claude" && exit 0

# ── Colors ───────────────────────────────────────────────────────────────────
r='\033[0m'
dim='\033[2m'
c_model='\033[38;2;180;140;255m'  # purple
c_dir='\033[38;2;86;182;194m'     # cyan
c_branch='\033[38;2;200;200;200m' # silver
c_dirty='\033[38;2;255;180;50m'   # amber
c_time='\033[38;2;140;160;180m'   # steel
c_dot='\033[38;2;80;80;100m'      # muted
c_add='\033[38;2;0;200;80m'       # green
c_del='\033[38;2;255;85;85m'      # red

# ── Helpers ───────────────────────────────────────────────────────────────────
zone_color() {
    case "$1" in
        Dumb)    printf '\033[38;2;255;85;85m'  ;;
        Caution) printf '\033[38;2;230;200;0m'  ;;
        Watch)   printf '\033[38;2;255;176;85m' ;;
        *)       printf '\033[38;2;0;175;80m'   ;;
    esac
}

zone_name() {
    local pct=$1
    if   [ "$pct" -ge 80 ]; then printf "Dumb"
    elif [ "$pct" -ge 60 ]; then printf "Caution"
    elif [ "$pct" -ge 40 ]; then printf "Watch"
    else printf "Smart"
    fi
}

fmt_tokens() {
    local n=$1
    if   [ "$n" -ge 1000000 ]; then awk "BEGIN{printf \"%.1fm\",$n/1000000}"
    elif [ "$n" -ge 1000 ];    then awk "BEGIN{printf \"%.0fk\",$n/1000}"
    else printf "%d" "$n"
    fi
}

build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 )) empty=$(( width - pct * width / 100 ))
    local zc; zc=$(zone_color "$(zone_name "$pct")")
    local f="" e=""
    for ((i=0; i<filled; i++)); do f+="▰"; done
    for ((i=0; i<empty;  i++)); do e+="▱"; done
    printf "${zc}${f}${dim}${e}${r}"
}

fmt_epoch() {
    local ep=$1 style=$2
    [ -z "$ep" ] || [ "$ep" = "null" ] && return
    case "$style" in
        time)
            date -r "$ep" +"%l:%M%p" 2>/dev/null | sed 's/^ //;s/\.//g' | tr '[:upper:]' '[:lower:]' \
            || date -d "@$ep" +"%l:%M%P" 2>/dev/null | sed 's/^ //;s/\.//g'
            ;;
        datetime)
            date -r "$ep" +"%b %-d, %l:%M%p" 2>/dev/null | sed 's/  / /g;s/^ //;s/\.//g' | tr '[:upper:]' '[:lower:]' \
            || date -d "@$ep" +"%b %-d, %l:%M%P" 2>/dev/null | sed 's/  / /g;s/^ //;s/\.//g'
            ;;
    esac
}

# ── Parse JSON ────────────────────────────────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')

ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 1000000')
[ "$ctx_size" -eq 0 ] 2>/dev/null && ctx_size=1000000

inp_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cw_tok=$(echo "$input"  | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cr_tok=$(echo "$input"  | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
used=$(( inp_tok + cw_tok + cr_tok ))

tokens=$(fmt_tokens $used)
pct=$(( used * 100 / ctx_size ))
[ "$pct" -gt 100 ] 2>/dev/null && pct=100
zone=$(zone_name "$pct")
zc=$(zone_color "$zone")

# Real cost from payload
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
if [ -n "$cost_usd" ]; then
    cost=$(awk "BEGIN{printf \"\$%.2f\", $cost_usd}")
else
    cost=""
fi

# Session
session_id=$(echo "$input"   | jq -r '.session_id // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')

# Duration from total_duration_ms
dur_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
duration=""
if [ "$dur_ms" -gt 0 ] 2>/dev/null; then
    elapsed=$(( dur_ms / 1000 ))
    if   [ "$elapsed" -ge 3600 ]; then duration="$(( elapsed/3600 ))h$(( (elapsed%3600)/60 ))m"
    elif [ "$elapsed" -ge 60 ];   then duration="$(( elapsed/60 ))m"
    else duration="${elapsed}s"
    fi
fi

# Effort from payload
effort=$(echo "$input" | jq -r '.effort.level // "default"')
case "$effort" in
    high)   effort_fmt="▲ high"    ;;
    medium) effort_fmt="◆ medium"  ;;
    low)    effort_fmt="▽ low"     ;;
    *)      effort_fmt="◆ default" ;;
esac

# Rate limits from payload (no API call needed)
fh_pct=$(echo "$input"      | jq -r '.rate_limits.five_hour.used_percentage // empty')
fh_rst_ep=$(echo "$input"   | jq -r '.rate_limits.five_hour.resets_at // empty')
sd_pct=$(echo "$input"      | jq -r '.rate_limits.seven_day.used_percentage // empty')
sd_rst_ep=$(echo "$input"   | jq -r '.rate_limits.seven_day.resets_at // empty')

# Git
cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
dir=$(basename "$cwd")

branch="" dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && dirty="*"
fi

# Lines added/removed from session (payload)
diff_add=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
diff_del=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

# ── OAuth (only for plan + extra usage) ──────────────────────────────────────
get_token() {
    [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] && { echo "$CLAUDE_CODE_OAUTH_TOKEN"; return; }
    if command -v security >/dev/null 2>&1; then
        local blob t
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        t=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        [ -n "$t" ] && [ "$t" != "null" ] && { echo "$t"; return; }
    fi
    local f="$HOME/.claude/.credentials.json"
    if [ -f "$f" ]; then
        local t; t=$(jq -r '.claudeAiOauth.accessToken // empty' "$f" 2>/dev/null)
        [ -n "$t" ] && [ "$t" != "null" ] && { echo "$t"; return; }
    fi
    if command -v secret-tool >/dev/null 2>&1; then
        local blob t
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        t=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        [ -n "$t" ] && [ "$t" != "null" ] && { echo "$t"; return; }
    fi
}

cache="/tmp/claude/ctxstat-cache.json"
mkdir -p /tmp/claude
usage=""

if [ -f "$cache" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null) ))
    [ "$age" -lt 60 ] && usage=$(cat "$cache" 2>/dev/null)
fi

if [ -z "$usage" ]; then
    tok=$(get_token)
    if [ -n "$tok" ] && [ "$tok" != "null" ]; then
        resp=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Authorization: Bearer $tok" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: ctxstat/1.0" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        echo "$resp" | jq -e '.five_hour' >/dev/null 2>&1 && {
            usage="$resp"; echo "$resp" > "$cache"
        }
    fi
    [ -z "$usage" ] && [ -f "$cache" ] && usage=$(cat "$cache" 2>/dev/null)
fi

# ── Plan detection ────────────────────────────────────────────────────────────
plan=""
if [ -n "$usage" ] && echo "$usage" | jq -e . >/dev/null 2>&1; then
    disabled_reason=$(echo "$usage" | jq -r '.extra_usage.disabled_reason // empty')
    extra_enabled=$(echo "$usage"   | jq -r '.extra_usage.is_enabled // false')
    if [[ "$disabled_reason" == *"org_level"* ]]; then
        plan="Teams"
    elif [ "$extra_enabled" = "true" ]; then
        plan="Max"
    else
        plan="Pro"
    fi
elif [ -n "$fh_pct" ]; then
    plan="Pro"
fi

# ── Build rows ────────────────────────────────────────────────────────────────
sep=" ${c_dot}·${r} "
ctx_bar=$(build_bar "$pct" 10)

# Row 1: model · tokens/% zone bar · cost · effort · plan
row1="${c_model}◆ ${model}${r}"
row1+="${sep}${dim}Tokens${r} ${zc}${tokens}/${pct}% (${zone})${r} ${ctx_bar}"
[ -n "$cost" ] && row1+="  ${cost}"
row1+="${sep}${dim}${effort_fmt}${r}"
[ -n "$plan" ] && row1+="${sep}${dim}${plan}${r}"

# Row 2: dir (branch) +add -del
row2="${c_dir}${dir}${r}"
if [ -n "$branch" ]; then
    row2+=" ${c_branch}(${branch}${c_dirty}${dirty}${c_branch})${r}"
    [ -n "$diff_add" ] && row2+=" ${c_add}+${diff_add}${r}"
    [ -n "$diff_del" ] && row2+=" ${c_del}-${diff_del}${r}"
fi

# Row 3: duration · session name (or id fallback)
row3=""
[ -n "$duration" ] && row3+="${c_time}${duration}${r}"
if [ -n "$session_name" ]; then
    [ -n "$row3" ] && row3+="${sep}"
    row3+="${dim}${session_name}${r}"
elif [ -n "$session_id" ]; then
    [ -n "$row3" ] && row3+="${sep}"
    row3+="${dim}${session_id}${r}"
fi

# ── Rate limit line (from payload) ───────────────────────────────────────────
rate_line=""

if [ -n "$fh_pct" ]; then
    bw=8
    fh_bar=$(build_bar "$fh_pct" "$bw")
    fh_zc=$(zone_color "$(zone_name "$fh_pct")")
    fh_rst=$(fmt_epoch "$fh_rst_ep" "time")

    sd_bar=$(build_bar "$sd_pct" "$bw")
    sd_zc=$(zone_color "$(zone_name "$sd_pct")")
    sd_rst=$(fmt_epoch "$sd_rst_ep" "datetime")

    rate_line="  ${dim}current${r} ${fh_bar} ${fh_zc}${fh_pct}%${r} ${c_time}→ ${fh_rst}${r}"
    rate_line+="   ${dim}╱${r}   "
    rate_line+="${dim}weekly${r} ${sd_bar} ${sd_zc}${sd_pct}%${r} ${c_time}→ ${sd_rst}${r}"
fi

# Extra usage from OAuth (Max plan)
if [ -n "$usage" ] && echo "$usage" | jq -e . >/dev/null 2>&1; then
    extra=$(echo "$usage" | jq -r '.extra_usage.is_enabled // false')
    if [ "$extra" = "true" ]; then
        ex_pct=$(echo "$usage"  | jq -r '.extra_usage.utilization // 0'   | awk '{printf "%.0f",$1}')
        ex_used=$(echo "$usage" | jq -r '.extra_usage.used_credits // 0'  | awk '{printf "%.2f",$1/100}')
        ex_lim=$(echo "$usage"  | jq -r '.extra_usage.monthly_limit // 0' | awk '{printf "%.2f",$1/100}')
        ex_bar=$(build_bar "$ex_pct" "$bw")
        ex_zc=$(zone_color "$(zone_name "$ex_pct")")
        rate_line+="\n  ${dim}extra${r} ${ex_bar} ${ex_zc}\$${ex_used}${dim}/${r}\$${ex_lim}"
    fi
fi

# ── Output ────────────────────────────────────────────────────────────────────
printf "%b" "$row1"
printf "\n%b" "$row2"
[ -n "$row3" ] && printf "\n%b" "$row3"
[ -n "$rate_line" ] && printf "\n\n%b" "$rate_line"
exit 0
