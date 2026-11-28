#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved.
fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

systemctl is-active --quiet dnsmasq || fail "the DNS server should be running" \
  "see: systemctl status dnsmasq"

for name in api.shop.internal db.shop.internal status.shop.internal; do
  want=$(dig +short @127.0.0.5 "$name" A)
  got=$(getent hosts "$name" | awk 'NR == 1 { print $1 }')
  [ "$got" = "$want" ] || fail "$name should resolve to its DNS address" \
    "expected: $want (what the DNS server at 127.0.0.5 says)" "got:      ${got:-nothing}" \
    "getent hosts $name shows what programs see; dig asks a DNS server directly"
done

if grep -v '^[[:space:]]*#' /etc/hosts | grep -q 'shop\.internal'; then
  fail "shop.internal names should come from DNS, not /etc/hosts" \
    "found:    $(grep -v '^[[:space:]]*#' /etc/hosts | grep 'shop\.internal' | head -n 1)" \
    "a hosts entry wins over DNS and goes stale when the address changes"
fi

body=$(curl -s --max-time 5 http://api.shop.internal/)
[ "$body" = "shop api: ok" ] || fail "curl http://api.shop.internal/ should answer" \
  "expected: shop api: ok" "got:      ${body:-no answer}"

echo "shop.internal resolves through DNS again, and the API answers"
