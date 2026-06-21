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

session_cost() {
    local name=$1 inp=$2 cw=$3 cr=$4
    local pi pw pr
    case "$name" in
        *"Fable 5"*|*"Mythos"*) pi=10;  pw=12.5; pr=1.0  ;;
        *"Opus"*)               pi=5;   pw=6.25; pr=0.5  ;;
        *"Haiku"*)              pi=1;   pw=1.25; pr=0.1  ;;
        *)                      pi=3;   pw=3.75; pr=0.3  ;;
    esac
    awk "BEGIN{
        c=($inp*$pi+$cw*$pw+$cr*$pr)/1000000
        if(c<0.001)     printf \"~\$0.00\"
        else if(c<0.1)  printf \"~\$%.3f\",c
        else            printf \"~\$%.2f\",c
    }"
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

iso_to_epoch() {
    local s="$1" e
    e=$(date -d "$s" +%s 2>/dev/null) && { echo "$e"; return 0; }
    local st="${s%%.*}"; st="${st%%Z}"; st="${st%%+*}"; st="${st%%-[0-9][0-9]:[0-9][0-9]}"
    if [[ "$s" == *Z* ]] || [[ "$s" == *+00:00* ]]; then
        e=$(env TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$st" +%s 2>/dev/null)
    else
        e=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$st" +%s 2>/dev/null)
    fi
    [ -n "$e" ] && echo "$e"
}

fmt_reset() {
    local iso=$1 style=$2
    [ -z "$iso" ] || [ "$iso" = "null" ] && return
    local ep; ep=$(iso_to_epoch "$iso"); [ -z "$ep" ] && return
    case "$style" in
        time)
            date -j -r "$ep" +"%l:%M%p" 2>/dev/null | sed 's/^ //;s/\.//g' | tr '[:upper:]' '[:lower:]' \
            || date -d "@$ep" +"%l:%M%P" 2>/dev/null | sed 's/^ //;s/\.//g'
            ;;
        datetime)
            date -j -r "$ep" +"%b %-d, %l:%M%p" 2>/dev/null | sed 's/  / /g;s/^ //;s/\.//g' | tr '[:upper:]' '[:lower:]' \
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
cost=$(session_cost "$model" "$inp_tok" "$cw_tok" "$cr_tok")

effort="default"
[ -f "$HOME/.claude/settings.json" ] && \
    effort=$(jq -r '.effortLevel // "default"' "$HOME/.claude/settings.json" 2>/dev/null)

cwd=$(echo "$input" | jq -r '.cwd // ""')
[ -z "$cwd" ] || [ "$cwd" = "null" ] && cwd=$(pwd)
dir=$(basename "$cwd")

branch="" dirty=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ] && dirty="*"
fi

duration=""
sess_start=$(echo "$input" | jq -r '.session.start_time // empty')
if [ -n "$sess_start" ] && [ "$sess_start" != "null" ]; then
    ep=$(iso_to_epoch "$sess_start")
    if [ -n "$ep" ]; then
        elapsed=$(( $(date +%s) - ep ))
        if   [ "$elapsed" -ge 3600 ]; then duration="$(( elapsed/3600 ))h$(( (elapsed%3600)/60 ))m"
        elif [ "$elapsed" -ge 60 ];   then duration="$(( elapsed/60 ))m"
        else duration="${elapsed}s"
        fi
    fi
fi

case "$effort" in
    high)   effort_fmt="▲ high"    ;;
    medium) effort_fmt="◆ medium"  ;;
    low)    effort_fmt="▽ low"     ;;
    *)      effort_fmt="◆ default" ;;
esac

# ── Line 1 ────────────────────────────────────────────────────────────────────
sep=" ${c_dot}·${r} "

line1="${c_model}◆ ${model}${r}"
line1+="${sep}${zc}${tokens} ${pct}% ${zone}${r}  ${dim}${cost}${r}"
line1+="${sep}${c_dir}${dir}${r}"
[ -n "$branch" ] && line1+=" ${c_branch}(${branch}${c_dirty}${dirty}${c_branch})${r}"
[ -n "$duration" ] && line1+="${sep}${c_time}${duration}${r}"
line1+="${sep}${dim}${effort_fmt}${r}"

# ── OAuth token ───────────────────────────────────────────────────────────────
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

# ── Usage cache ───────────────────────────────────────────────────────────────
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

# ── Rate limit line ───────────────────────────────────────────────────────────
rate_line=""

if [ -n "$usage" ] && echo "$usage" | jq -e . >/dev/null 2>&1; then
    bw=8

    fh_pct=$(echo "$usage" | jq -r '.five_hour.utilization // 0' | awk '{printf "%.0f",$1}')
    fh_rst=$(fmt_reset "$(echo "$usage" | jq -r '.five_hour.resets_at // empty')" "time")
    fh_bar=$(build_bar "$fh_pct" "$bw")
    fh_zc=$(zone_color "$(zone_name "$fh_pct")")

    sd_pct=$(echo "$usage" | jq -r '.seven_day.utilization // 0' | awk '{printf "%.0f",$1}')
    sd_rst=$(fmt_reset "$(echo "$usage" | jq -r '.seven_day.resets_at // empty')" "datetime")
    sd_bar=$(build_bar "$sd_pct" "$bw")
    sd_zc=$(zone_color "$(zone_name "$sd_pct")")

    rate_line="  ${dim}current${r} ${fh_bar} ${fh_zc}${fh_pct}%${r} ${c_time}→ ${fh_rst}${r}"
    rate_line+="   ${dim}╱${r}   "
    rate_line+="${dim}weekly${r} ${sd_bar} ${sd_zc}${sd_pct}%${r} ${c_time}→ ${sd_rst}${r}"

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
printf "%b" "$line1"
[ -n "$rate_line" ] && printf "\n\n%b" "$rate_line"
exit 0
