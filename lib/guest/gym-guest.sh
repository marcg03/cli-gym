# In-VM `gym` command: task, check, answer.
set -uo pipefail
dir=/etc/cligym

bold=$'\e[1m'; green=$'\e[32m'; red=$'\e[31m'; dim=$'\e[2m'; reset=$'\e[0m'

cmd_task() {
  echo "${bold}$(jq -r '"\(.title)  [\(.id) · seed \(.seed) · \(.difficulty)]"' "$dir/meta.json")${reset}"
  echo
  cat "$dir/task.md"
  echo
  echo "${dim}Commands: gym task · gym check · gym answer · poweroff to leave${reset}"
}

cmd_answer() {
  if [ "${1:-}" != -y ]; then
    read -rp "Reveal the answer? [y/N] " yn
    [[ $yn == [yY]* ]] || return 0
  fi
  echo
  cat "$dir/answer.md"
}

sha() { sha256sum | cut -d' ' -f1; }

# Runs probe $1 (JSON). Returns 0 on pass.
run_probe() {
  local p=$1 type path expected out rc
  type=$(jq -r .type <<<"$p")
  case $type in
    file)
      path=$(jq -r .path <<<"$p"); [[ $path == /* ]] || path=/root/$path
      expected=$(jq -r '.sha256 // empty' <<<"$p")
      [ -z "$expected" ] && expected=$(cat "$(jq -r .sha256File <<<"$p")")
      [ -f "$path" ] && [ "$(sha < "$path")" = "$expected" ]
      ;;
    command)
      out=$(cd /root && bash -c "$(jq -r .run <<<"$p")" 2>/dev/null); rc=$?
      [ "$rc" -eq "$(jq -r .exitCode <<<"$p")" ] || return 1
      if [ "$(jq -r '.stdout != null' <<<"$p")" = true ]; then
        [ "$out" = "$(jq -r .stdout <<<"$p")" ] || return 1
      fi
      if [ "$(jq -r '.sha256 != null' <<<"$p")" = true ]; then
        [ "$(printf '%s\n' "$out" | sha)" = "$(jq -r .sha256 <<<"$p")" ] || return 1
      fi
      ;;
    *) echo "unknown probe type $type" >&2; return 2 ;;
  esac
}

cmd_check() {
  local n i p desc fb
  n=$(jq length "$dir/checks.json")
  for ((i = 0; i < n; i++)); do
    p=$(jq -c ".[$i]" "$dir/checks.json")
    desc=$(jq -r .description <<<"$p")
    if run_probe "$p"; then
      echo "${green}✓${reset} $desc"
    else
      echo "${red}✗${reset} $desc"
      fb=$(jq -r '.feedback // empty' <<<"$p")
      [ -n "$fb" ] && echo "  ${dim}$fb${reset}"
      for ((i = i + 1; i < n; i++)); do echo "${dim}· $(jq -r ".[$i].description" "$dir/checks.json")${reset}"; done
      return 1
    fi
  done
  echo
  echo "${bold}${green}Solved!${reset} Compare with the reference: gym answer"
}

case "${1:-task}" in
  task) cmd_task ;;
  answer) shift; cmd_answer "$@" ;;
  check) cmd_check ;;
  *) echo "usage: gym [task|check|answer]" >&2; exit 2 ;;
esac
