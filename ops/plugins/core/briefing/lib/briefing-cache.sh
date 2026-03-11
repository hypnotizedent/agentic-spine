#!/usr/bin/env bash
set -euo pipefail

briefing_cache_file() {
  local cache_dir="$1"
  local section_id="$2"
  printf '%s/%s.json' "$cache_dir" "$section_id"
}

briefing_cache_is_fresh() {
  local cache_dir="$1"
  local section_id="$2"
  local ttl_seconds="$3"
  local file now modified age

  file="$(briefing_cache_file "$cache_dir" "$section_id")"
  [[ -f "$file" ]] || return 1

  now="$(date +%s)"
  modified="$(stat -f %m "$file" 2>/dev/null || echo 0)"
  [[ "$modified" =~ ^[0-9]+$ ]] || return 1
  age=$(( now - modified ))

  (( age <= ttl_seconds ))
}

briefing_cache_read() {
  local cache_dir="$1"
  local section_id="$2"
  local file

  file="$(briefing_cache_file "$cache_dir" "$section_id")"
  [[ -f "$file" ]] || return 1
  cat "$file"
}

briefing_cache_write() {
  local cache_dir="$1"
  local section_id="$2"
  local payload="$3"
  local file

  mkdir -p "$cache_dir"
  file="$(briefing_cache_file "$cache_dir" "$section_id")"
  printf '%s\n' "$payload" >"$file"
}

briefing_cache_clear() {
  local cache_dir="$1"
  rm -rf "$cache_dir"
}
