#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved.
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

copy=/root/ledger.log.1
[ -f "$copy" ] || fail "the deleted log should be rescued first" \
  "expected: a copy at $copy" "got:      no such file" \
  "once its space is freed, the old log is gone for good"
grep -qF "settlement day 2026-11-27 opened" "$copy" \
  && grep -qF "settlement day 2026-11-27 closed" "$copy" \
  || fail "the rescued copy should hold the whole old log" \
    "expected: both the 'day opened' and the 'day closed' lines" \
    "got:      $(wc -c < "$copy") bytes without both"

used=$(df --output=pcent /var/log/ledger | tail -n 1 | tr -dc 0-9)
[ "$used" -lt 50 ] || fail "/var/log/ledger should be under 50% used" \
  "expected: under 50%" "got:      $used%" \
  "deleting a file only frees its space once no process has it open"

echo "old log rescued, /var/log/ledger is at $used% and ledger is still running as PID $pid"
