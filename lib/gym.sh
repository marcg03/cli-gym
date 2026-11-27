# In-VM `gym` command. $TITLE, $TASK, $ANSWER, $CHECK and $CHALLENGE are set by lib/default.nix.
case "${1:-task}" in
  task)
    echo "$TITLE"
    echo
    cat "$TASK"
    echo
    echo "Commands: gym task | gym check | gym answer | poweroff to leave"
    ;;
  check)
    # The challenge's check prints its own feedback; we only add the verdict.
    (cd /root && CHALLENGE=$CHALLENGE "$CHECK")
    rc=$?
    echo
    if [ "$rc" -eq 0 ]; then echo "PASS"; else echo "FAIL (check exited $rc)"; fi
    exit "$rc"
    ;;
  answer)
    if [ "${2:-}" != -y ]; then
      read -rp "Reveal the answer? [y/N] " yn
      [[ $yn == [yY]* ]] || exit 0
    fi
    echo
    cat "$ANSWER"
    ;;
  *) echo "usage: gym [task|check|answer]" >&2; exit 2 ;;
esac
