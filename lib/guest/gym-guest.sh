# In-VM `gym` command: task, check, answer.
set -uo pipefail
dir=/etc/cligym

cmd_task() {
  jq -r '"\(.title) [\(.id), \(.difficulty)]"' "$dir/meta.json"
  jq -r '"Seed \(.seed). Another world: GYM_SEED=<n> nix run --impure .#\(.id)"' "$dir/meta.json"
  echo
  cat "$dir/task.md"
  echo
  echo "Commands: gym task | gym check | gym answer | poweroff to leave"
}

cmd_answer() {
  if [ "${1:-}" != -y ]; then
    read -rp "Reveal the answer? [y/N] " yn
    [[ $yn == [yY]* ]] || return 0
  fi
  echo
  cat "$dir/answer.md"
}

# The challenge's own check prints its feedback; the runner only adds the verdict.
cmd_check() {
  (cd /root && "$dir/check")
  local rc=$?
  echo
  if [ "$rc" -eq 0 ]; then echo "PASS"; else echo "FAIL (check exited $rc)"; fi
  return "$rc"
}

case "${1:-task}" in
  task) cmd_task ;;
  check) cmd_check ;;
  answer) shift; cmd_answer "$@" ;;
  *) echo "usage: gym [task|check|answer]" >&2; exit 2 ;;
esac
