#!/usr/bin/env bash
# Exit 0 = solved. Prints its own feedback.
fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

systemctl is-active --quiet ledger || fail "the ledger service should be running" \
  "see: systemctl status ledger"

pid=$(systemctl show -p MainPID --value ledger)
[ "$pid" = "$(cat /run/ledger.pid)" ] || fail "the ledger service was restarted" \
  "expected: main PID $(cat /run/ledger.pid)" "got:      $pid" \
  "a restart frees the space, but it interrupts payments; find a way without one"

got=$(ls /var/log/ledger/audit-*.log 2>/dev/null | wc -l)
[ "$got" = 3 ] || fail "the audit logs should be kept" \
  "expected: 3 audit-*.log files" "got:      $got"

used=$(df --output=pcent /var/log/ledger | tail -n 1 | tr -dc 0-9)
[ "$used" -lt 50 ] || fail "/var/log/ledger should be under 50% used" \
  "expected: under 50%" "got:      $used%" \
  "deleting a file only frees its space once no process has it open"

echo "/var/log/ledger is at $used% and ledger is still running as PID $pid"
