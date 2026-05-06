#!/bin/bash
# Status line command for Claude Code with oh-my-posh integration

# Load common functions
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Get script directory and version
script_dir=$(get_script_dir)
VERSION=$(get_version "$script_dir")
handle_version_flag "$1" "$VERSION"

# Read JSON input from stdin
input=$(cat)

# Extract values using jq
model=$(echo "$input" | jq -r '.model.display_name')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Calculate context usage — percentage, bar components, and color state
usage=$(echo "$input" | jq '.context_window.current_usage')
context_pct=""
context_pct_num=""
context_state="ok"
context_bar_filled=""
context_bar_empty=""
context_bar_color="#7ec8a4"
context_remaining=""

if [ "$usage" != "null" ]; then
    input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
    cache_creation=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
    cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
    size=$(echo "$input" | jq '.context_window.context_window_size // 1')

    # Calculate current usage using awk (no bc dependency)
    current=$(awk "BEGIN {print $input_tokens + $cache_creation + $cache_read}")
    if [ "$size" != "0" ]; then
        pct=$(awk "BEGIN {printf \"%.0f\", $current * 100 / $size}")
    else
        pct=0
    fi

    context_pct="${pct}%"
    context_pct_num="$pct"

    # Build 20-block visual bar — filled and empty portions kept separate
    # so templates can color them independently
    bar_width=20
    bar_block="▪"
    bar_filled_count=$(( pct * bar_width / 100 ))
    bar_empty_count=$(( bar_width - bar_filled_count ))

    for ((i=0; i<bar_filled_count; i++)); do context_bar_filled+="$bar_block"; done
    for ((i=0; i<bar_empty_count; i++)); do context_bar_empty+="$bar_block"; done

    # Format tokens remaining
    context_remaining=$(awk -v cur="$current" -v sz="$size" 'BEGIN {
        r = sz - cur
        if (r >= 1000000) printf "%.1fM", r/1000000
        else if (r >= 1000) printf "%.0fK", r/1000
        else printf "%d", r
    }')

    # Color state and bar color — warn at 75%, danger at 90%
    if [ "$pct" -ge 90 ]; then
        context_state="danger"
        context_bar_color="#e87070"
    elif [ "$pct" -ge 75 ]; then
        context_state="warning"
        context_bar_color="#e6c96a"
    fi
fi

# Fetch usage data - render from cache immediately, then kick off a background refresh
cache_file="$script_dir/.usage_cache"
update_script="$script_dir/update-usage.sh"

# Always trigger a background refresh after each render, unless one is already running
! pgrep -f "update-usage.sh" > /dev/null 2>&1 && bash "$update_script" &>/dev/null &

# Read cache for current render (may be stale on the very first render after startup)
if [ -f "$cache_file" ]; then
    cache_json=$(cat "$cache_file" 2>/dev/null)
    session_tokens=$(echo "$cache_json" | jq -r '.code.session_tokens // 0')
    pro_five_hour_usage=$(echo "$cache_json" | jq -r '.pro.five_hour_pct // empty')
    pro_seven_day_usage=$(echo "$cache_json" | jq -r '.pro.seven_day_pct // empty')
    pro_five_hour_resets=$(echo "$cache_json" | jq -r '.pro.five_hour_resets_at // empty')
    pro_seven_day_resets=$(echo "$cache_json" | jq -r '.pro.seven_day_resets_at // empty')
else
    session_tokens=""
    pro_five_hour_usage=""
    pro_seven_day_usage=""
    pro_five_hour_resets=""
    pro_seven_day_resets=""
fi

# Format Code usage display (tokens only) - using only awk
code_usage_display=""
if [ -n "$session_tokens" ] && [ "$session_tokens" != "0" ]; then
    session_m=$(awk -v t="$session_tokens" 'BEGIN {v=t/1000000; printf(v==int(v)?"%.0f":"%.1f", v)}')
    code_usage_display="${session_m}M"
fi

# Format Pro usage display and per-metric bar components
bar_width=20
bar_block="▪"
pro_usage_display=""
pro_state="ok"
pro_5h_pct=""
pro_5h_bar_filled=""
pro_5h_bar_empty=""
pro_5h_bar_color="#7ec8a4"
pro_5h_state="ok"
pro_7d_pct=""
pro_7d_bar_filled=""
pro_7d_bar_empty=""
pro_7d_bar_color="#7ec8a4"
pro_7d_state="ok"

if [ -n "$pro_five_hour_usage" ] && [ -n "$pro_seven_day_usage" ]; then
    pro_usage_display="5h:${pro_five_hour_usage}% 7d:${pro_seven_day_usage}%"
    pro_5h_pct="$pro_five_hour_usage"
    pro_7d_pct="$pro_seven_day_usage"

    # 5h bar
    pro_5h_filled_count=$(( pro_five_hour_usage * bar_width / 100 ))
    pro_5h_empty_count=$(( bar_width - pro_5h_filled_count ))
    for ((i=0; i<pro_5h_filled_count; i++)); do pro_5h_bar_filled+="$bar_block"; done
    for ((i=0; i<pro_5h_empty_count; i++)); do pro_5h_bar_empty+="$bar_block"; done
    if [ "$pro_five_hour_usage" -ge 80 ]; then
        pro_5h_state="danger"
        pro_5h_bar_color="#e87070"
    fi

    # 7d bar
    pro_7d_filled_count=$(( pro_seven_day_usage * bar_width / 100 ))
    pro_7d_empty_count=$(( bar_width - pro_7d_filled_count ))
    for ((i=0; i<pro_7d_filled_count; i++)); do pro_7d_bar_filled+="$bar_block"; done
    for ((i=0; i<pro_7d_empty_count; i++)); do pro_7d_bar_empty+="$bar_block"; done
    if [ "$pro_seven_day_usage" -ge 80 ]; then
        pro_7d_state="danger"
        pro_7d_bar_color="#e87070"
    fi

    # Combined state: danger if either metric is
    if [ "$pro_5h_state" = "danger" ] || [ "$pro_7d_state" = "danger" ]; then
        pro_state="danger"
    fi
fi

# Format reset times display and individual components
reset_display=""
reset_5h_hours=""
reset_5h_mins=""
reset_5h_resetting="false"
reset_7d_day=""
reset_7d_time=""

if [ -n "$pro_five_hour_resets" ] && [ -n "$pro_seven_day_resets" ]; then
    # Normalize timestamps: remove milliseconds and strip colon from timezone
    # offset (e.g. +00:00 → +0000) for macOS date compatibility
    five_hour_clean=$(echo "$pro_five_hour_resets" | sed 's/\.[0-9]*+/+/' | sed 's/+\([0-9][0-9]\):\([0-9][0-9]\)$/+\1\2/')
    seven_day_clean=$(echo "$pro_seven_day_resets" | sed 's/\.[0-9]*+/+/' | sed 's/+\([0-9][0-9]\):\([0-9][0-9]\)$/+\1\2/')

    # Get current time and reset time in seconds since epoch
    now_sec=$(date +%s)
    five_hour_sec=$(parse_date "$five_hour_clean")

    if [ -n "$five_hour_sec" ]; then
        diff_sec=$((five_hour_sec - now_sec))

        if [ "$diff_sec" -gt 0 ]; then
            hours=$((diff_sec / 3600))
            mins=$(((diff_sec % 3600) / 60))
            five_hour_display="${hours}h${mins}min"
            reset_5h_hours="$hours"
            reset_5h_mins="$mins"
        else
            five_hour_display="resetting..."
            reset_5h_resetting="true"
        fi
    else
        five_hour_display="?"
    fi

    # Format 7-day reset time (day + time)
    seven_day_day=$(format_date "+%a" "$seven_day_clean")
    seven_day_time=$(format_date "+%H:%M" "$seven_day_clean")

    if [ -n "$seven_day_day" ] && [ -n "$seven_day_time" ]; then
        seven_day_display="${seven_day_day}${seven_day_time}"
        reset_7d_day="$seven_day_day"
        reset_7d_time="$seven_day_time"
    else
        seven_day_display="?"
    fi

    reset_display="5h:${five_hour_display} 7d:${seven_day_display}"
fi

# Path to oh-my-posh config file
layout="${OH_MY_CLAUDE_LAYOUT:-duo}"
config_file="$script_dir/claude-statusline-${layout}.omp.json"

# Use oh-my-posh to render the status line with clean environment
env -i \
  HOME="$HOME" \
  CLAUDE_MODEL="$model" \
  CLAUDE_CONTEXT="$context_pct" \
  CLAUDE_CONTEXT_PCT="$context_pct_num" \
  CLAUDE_CONTEXT_BAR_FILLED="$context_bar_filled" \
  CLAUDE_CONTEXT_BAR_EMPTY="$context_bar_empty" \
  CLAUDE_CONTEXT_BAR_COLOR="$context_bar_color" \
  CLAUDE_CONTEXT_REMAINING="$context_remaining" \
  CLAUDE_CONTEXT_STATE="$context_state" \
  CLAUDE_CODE_USAGE="$code_usage_display" \
  CLAUDE_PRO_USAGE="$pro_usage_display" \
  CLAUDE_PRO_STATE="$pro_state" \
  CLAUDE_PRO_5H_PCT="$pro_5h_pct" \
  CLAUDE_PRO_5H_BAR_FILLED="$pro_5h_bar_filled" \
  CLAUDE_PRO_5H_BAR_EMPTY="$pro_5h_bar_empty" \
  CLAUDE_PRO_5H_BAR_COLOR="$pro_5h_bar_color" \
  CLAUDE_PRO_5H_STATE="$pro_5h_state" \
  CLAUDE_PRO_7D_PCT="$pro_7d_pct" \
  CLAUDE_PRO_7D_BAR_FILLED="$pro_7d_bar_filled" \
  CLAUDE_PRO_7D_BAR_EMPTY="$pro_7d_bar_empty" \
  CLAUDE_PRO_7D_BAR_COLOR="$pro_7d_bar_color" \
  CLAUDE_PRO_7D_STATE="$pro_7d_state" \
  CLAUDE_RESET="$reset_display" \
  CLAUDE_RESET_5H_HOURS="$reset_5h_hours" \
  CLAUDE_RESET_5H_MINS="$reset_5h_mins" \
  CLAUDE_RESET_5H_RESETTING="$reset_5h_resetting" \
  CLAUDE_RESET_7D_DAY="$reset_7d_day" \
  CLAUDE_RESET_7D_TIME="$reset_7d_time" \
  PATH="$PATH" \
  oh-my-posh print primary --config "$config_file" --pwd "$cwd"
