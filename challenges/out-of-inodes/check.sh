#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved.
fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

systemctl is-active --quiet shop || fail "the shop service should be running" \
  "see: systemctl status shop"

itotal=$(df --output=itotal /srv | tail -n 1 | tr -dc 0-9)
[ "$itotal" = "$(cat /run/gym-inodes)" ] || fail "/srv should keep its size" \
  "expected: $(cat /run/gym-inodes) inodes in total" "got:      $itotal" \
  "on a real disk the inode count is fixed when it is formatted; clean up instead"

dump=/srv/shop/backup/shop-db-2026-11-27.sql
[ "$(stat -c %s "$dump" 2>/dev/null)" = $((30 * 1024 * 1024)) ] || fail "the database dump should be kept" \
  "expected: $dump, 30 MiB" "got:      missing or changed" \
  "deleting a big file frees blocks, but only one inode"

got=$(find /srv/shop/uploads -type f -name 'product-*.jpg' 2>/dev/null | wc -l)
[ "$got" = 300 ] || fail "the product images should be kept" \
  "expected: 300 files in /srv/shop/uploads" "got:      $got"

missing=0
for i in $(seq -w 1 20); do
  [ -f "/srv/shop/sessions/sess_live$i" ] || missing=$((missing + 1))
done
[ "$missing" = 0 ] || fail "customers who are logged in now should stay logged in" \
  "expected: all 20 sessions idle for less than 24 hours" "got:      $missing of them deleted" \
  "select by age: find can match on modification time"

used=$(df --output=ipcent /srv | tail -n 1 | tr -dc 0-9)
[ "$used" -le 50 ] || fail "at least half of the inodes on /srv should be free" \
  "expected: IUse% 50% or less (df -i /srv)" "got:      $used%"

echo "expired sessions gone, /srv is at $used% of its inodes, live sessions and data kept"
