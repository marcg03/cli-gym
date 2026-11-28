#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved. $CHALLENGE is this folder, for expected.conf.
fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

[ -f app.conf ] || fail "app.conf is missing"

got=$(grep -c '^db_host = db01.internal$' app.conf)
[ "$got" = 3 ] || fail "db_host should point at the new server" \
  "expected: 3 lines 'db_host = db01.internal'" "got:      $got"

got=$(grep -v '^#' app.conf | grep -c debug)
[ "$got" = 0 ] || fail "every uncommented line with debug should be commented out" \
  "expected: 0 uncommented debug lines" "got:      $got"

got=$(grep -c '^# #' app.conf)
[ "$got" = 0 ] || fail "existing comments should stay as they are" \
  "expected: 0 lines starting with '# #'" "got:      $got (the header was already a comment)"

diff -q "$CHALLENGE/expected.conf" app.conf > /dev/null \
  || fail "nothing else should change" "hint: did cache_host or db_hostname_check change?"

echo "app.conf looks right"
