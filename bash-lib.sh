#!/bin/bash
 
log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1"
}

log_error() {
  local message=$1
  echo -e "\e[31mERROR: $message\e[0m"
}

get_screen_count() {
    local output
    output=$(xrandr --screen 100 2>&1)
    echo "$output" | grep -oP '(?<=display has )\d+'
}
