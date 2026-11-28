#!/usr/bin/env bash
# Runs in /root. Exit 0 = solved.
fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

state=$(systemctl is-active nginx)
[ "$state" = active ] || fail "the nginx service should be running" \
  "expected: active" "got:      $state" \
  "see: systemctl status nginx"

status=$(curl -Is --max-time 5 127.0.0.1:80 | head -n 1 | tr -d '\r')
[ "$status" = "HTTP/1.1 200 OK" ] || fail "nginx should answer on port 80" \
  "expected: HTTP/1.1 200 OK" "got:      ${status:-no answer}" \
  "nginx logs to /var/log/nginx/error.log"

curl -s --max-time 5 127.0.0.1:80 | grep -q "Welcome to nginx!" \
  || fail "nginx should serve its default page" "expected: the 'Welcome to nginx!' page"

master=$(cat /run/nginx.pid 2>/dev/null)
[ "$master" = "$(systemctl show -p MainPID --value nginx)" ] || fail "nginx should run under systemd" \
  "expected: the nginx service's main process to be the nginx master" \
  "got:      an nginx that systemd does not manage; stop it and use systemctl"

echo "nginx answers HTTP/1.1 200 OK on port 80, run by systemd"
