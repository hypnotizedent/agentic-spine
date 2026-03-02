# Spine session command telemetry — source this in your zsh session
# Usage: source <session-dir>/preexec-hook.zsh
_spine_preexec() {
  local cmd="$1"
  local log="${SPINE_SESSION_DIR}/commands.log"
  [[ -n "${SPINE_SESSION_DIR:-}" ]] || return
  printf '%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(pwd)" "$cmd" >> "$log"
}
autoload -Uz add-zsh-hook
add-zsh-hook preexec _spine_preexec
