#!/bin/bash

# Usage: claude-usage.sh [5h|7d|all]
MODE="${1:-all}"

CACHE_DIR="$HOME/.cache"
API_CACHE_FILE="$CACHE_DIR/claude-api-response.json"
LOCK_FILE="$CACHE_DIR/claude-usage.lock"

[[ ! -d "$CACHE_DIR" ]] && mkdir -p "$CACHE_DIR"

# Tokyo Night Storm palette (tmux format)
C_RED="#[fg=#f7767e]"
C_YELLOW="#[fg=#e0af68]"
C_GRAY="#[fg=#565f89]"
C_DIM="#[fg=#3b4261]"
C_RESET="#[default]"

get_pct_color() {
  local pct="$1"
  if [[ $pct -gt 80 ]]; then
    echo "$C_RED"
  elif [[ $pct -gt 60 ]]; then
    echo "$C_YELLOW"
  else
    echo "$C_GRAY"
  fi
}

make_bar() {
  local pct="$1"
  local color="$2"
  local width=10
  local filled=$(( (pct * width + 50) / 100 ))
  local empty=$((width - filled))
  [[ $filled -gt $width ]] && filled=$width
  [[ $filled -lt 0 ]] && filled=0
  [[ $empty -lt 0 ]] && empty=0
  local bar_filled=""
  local bar_empty=""
  local i
  for ((i = 0; i < filled; i++)); do bar_filled+="▓"; done
  for ((i = 0; i < empty; i++));  do bar_empty+="░"; done
  printf "${color}${bar_filled}${C_DIM}${bar_empty}${C_RESET}"
}

get_file_age() {
  local file="$1"
  local mod_time=$(stat -c '%Y' "$file" 2>/dev/null)
  local now=$(date +%s)
  echo $((now - mod_time))
}

parse_iso_to_seconds_left() {
  local iso_date="$1"
  local clean_date=$(echo "$iso_date" | sed 's/\.[0-9]*//; s/+00:00//; s/Z$//')
  local reset_ts=$(date -u -d "$clean_date" "+%s" 2>/dev/null)
  if [[ -n "$reset_ts" ]]; then
    local now=$(date +%s)
    echo $((reset_ts - now))
  else
    echo ""
  fi
}

format_remaining_hm() {
  local seconds="$1"
  if [[ $seconds -le 0 ]]; then echo "0m"; return; fi
  local hours=$((seconds / 3600))
  local mins=$(((seconds % 3600) / 60))
  [[ $hours -gt 0 ]] && echo "${hours}h${mins}m" || echo "${mins}m"
}

format_remaining_dhm() {
  local seconds="$1"
  if [[ $seconds -le 0 ]]; then echo "0m"; return; fi
  local days=$((seconds / 86400))
  local hours=$(((seconds % 86400) / 3600))
  local mins=$(((seconds % 3600) / 60))
  if [[ $days -gt 0 ]]; then
    echo "${days}d${hours}h"
  elif [[ $hours -gt 0 ]]; then
    echo "${hours}h${mins}m"
  else
    echo "${mins}m"
  fi
}

fetch_api_data() {
  if [[ -f "$API_CACHE_FILE" ]]; then
    local age=$(get_file_age "$API_CACHE_FILE")
    if [[ $age -lt 60 ]]; then
      cat "$API_CACHE_FILE"
      return 0
    fi
  fi

  if [[ -f "$LOCK_FILE" ]]; then
    local lock_age=$(get_file_age "$LOCK_FILE")
    if [[ $lock_age -lt 30 ]]; then
      [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"
      return 0
    fi
  fi
  touch "$LOCK_FILE"

  local creds_file="$HOME/.claude/.credentials.json"
  [[ ! -f "$creds_file" ]] && { [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"; return 0; }

  local token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
  [[ -z "$token" ]] && { [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"; return 0; }

  local response=$(curl -s --max-time 5 "https://api.anthropic.com/api/oauth/usage" \
    -H "Authorization: Bearer $token" \
    -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null)

  if [[ -n "$response" ]]; then
    echo "$response" | tee "$API_CACHE_FILE"
  else
    [[ -f "$API_CACHE_FILE" ]] && cat "$API_CACHE_FILE"
  fi
}

format_block() {
  local pct_raw="$1"
  local reset_at="$2"
  local time_fmt_fn="$3"  # "hm" or "dhm"

  local pct=${pct_raw%.*}
  local color=$(get_pct_color "$pct")
  local bar=$(make_bar "$pct" "$color")

  local time_label
  if [[ -n "$reset_at" ]]; then
    local secs_left=$(parse_iso_to_seconds_left "$reset_at")
    if [[ "$time_fmt_fn" == "dhm" ]]; then
      time_label=$(format_remaining_dhm "$secs_left")
    else
      time_label=$(format_remaining_hm "$secs_left")
    fi
  else
    [[ "$time_fmt_fn" == "dhm" ]] && time_label="7d" || time_label="5h"
  fi

  printf "${color}%s: [${C_RESET}%s${color}] %s%%%s" "$time_label" "$bar" "$pct" "$C_RESET"
}

RESPONSE=$(fetch_api_data)
[[ -z "$RESPONSE" ]] && exit 0

session_pct=$(echo "$RESPONSE" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
weekly_pct=$(echo "$RESPONSE" | jq -r '.seven_day.utilization // empty' 2>/dev/null)

if [[ -z "$session_pct" && -z "$weekly_pct" ]]; then
  echo "${C_GRAY}∞ Max${C_RESET}"
  exit 0
fi

session_reset=$(echo "$RESPONSE" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)
weekly_reset=$(echo "$RESPONSE" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

case "$MODE" in
  5h)
    [[ -n "$session_pct" ]] && format_block "$session_pct" "$session_reset" "hm"
    ;;
  7d)
    [[ -n "$weekly_pct" ]] && format_block "$weekly_pct" "$weekly_reset" "dhm"
    ;;
  all|*)
    out5h=""
    out7d=""
    [[ -n "$session_pct" ]] && out5h=$(format_block "$session_pct" "$session_reset" "hm")
    [[ -n "$weekly_pct" ]] && out7d=$(format_block "$weekly_pct" "$weekly_reset" "dhm")
    if [[ -n "$out5h" && -n "$out7d" ]]; then
      echo "${out5h} ${C_GRAY}|${C_RESET} ${out7d}"
    elif [[ -n "$out5h" ]]; then
      echo "$out5h"
    elif [[ -n "$out7d" ]]; then
      echo "$out7d"
    fi
    ;;
esac
