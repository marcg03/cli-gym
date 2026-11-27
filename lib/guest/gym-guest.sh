# In-VM `gym` command: task, check, answer.
# Output is plain text and owned by this runner, so every challenge reports the same way.
set -uo pipefail
dir=/etc/cligym

cmd_task() {
  jq -r '"\(.title) [\(.id), seed \(.seed), \(.difficulty)]"' "$dir/meta.json"
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

sha() { sha256sum | cut -d' ' -f1; }
field() { jq -r "$1 // empty" <<<"$probe"; }
# Collapse output to one line for the report.
oneline() { printf '%s' "$1" | head -c 200 | tr '\n' '|'; }

# Runs $probe. On failure sets $what, $expected and $got and returns 1.
run_probe() {
  local type path want out rc
  type=$(field .type)
  case $type in
    file)
      path=$(field .path); [[ $path == /* ]] || path=/root/$path
      want=$(field .sha256); [ -z "$want" ] && want=$(cat "$(field .sha256File)")
      what="file $path"
      expected="sha256 $want"
      if [ ! -f "$path" ]; then got="file does not exist"; return 1; fi
      got="sha256 $(sha < "$path")"
      [ "$got" = "$expected" ]
      ;;
    command)
      what="command: $(field .run)"
      out=$(cd /root && bash -c "$(field .run)" 2>/dev/null); rc=$?
      expected="exit $(field .exitCode)"
      got="exit $rc"
      if [ "$(jq -r '.stdout != null' <<<"$probe")" = true ]; then
        expected+=", output \"$(field .stdout)\""
        got+=", output \"$(oneline "$out")\""
      fi
      [ "$got" = "$expected" ]
      ;;
    *) what="unknown probe type '$type'"; expected="file or command"; got="$type"; return 1 ;;
  esac
}

cmd_check() {
  local n i desc note
  n=$(jq length "$dir/checks.json")
  for ((i = 0; i < n; i++)); do
    probe=$(jq -c ".[$i]" "$dir/checks.json")
    desc=$(field .description)
    if ! run_probe; then
      echo "FAIL check $((i + 1))/$n: $desc"
      echo "  $what"
      echo "  expected: $expected"
      echo "  got:      $got"
      note=$(field .feedback)
      [ -n "$note" ] && echo "  note:     $note"
      return 1
    fi
  done
  echo "PASS all $n checks"
}

case "${1:-task}" in
  task) cmd_task ;;
  check) cmd_check ;;
  answer) shift; cmd_answer "$@" ;;
  *) echo "usage: gym [task|check|answer]" >&2; exit 2 ;;
esac
