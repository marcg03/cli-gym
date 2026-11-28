#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved.
fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

systemctl is-active --quiet dnsmasq || fail "the DNS server should be running" \
  "see: systemctl status dnsmasq"

ping -c 1 -W 2 api.shop.internal > /dev/null 2>&1 || fail "ping -c 1 api.shop.internal should work" \
  "got: $(ping -c 1 -W 2 api.shop.internal 2>&1 | head -n 1)"

if grep -v '^[[:space:]]*#' /etc/hosts | grep -q 'shop\.internal'; then
  fail "shop.internal names should come from DNS, not /etc/hosts" \
    "found:    $(grep -v '^[[:space:]]*#' /etc/hosts | grep 'shop\.internal' | head -n 1)"
fi

for name in api.shop.internal db.shop.internal status.shop.internal; do
  want=$(dig +short @127.0.0.5 "$name" A)
  got=$(getent hosts "$name" | awk 'NR == 1 { print $1 }')
  [ "$got" = "$want" ] || fail "$name should resolve to its DNS address" \
    "expected: $want (what the DNS server at 127.0.0.5 says)" "got:      ${got:-nothing}"
done

echo "shop.internal names resolve through DNS again"
