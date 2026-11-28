The shop API on this machine has stopped answering by name:

    curl http://api.shop.internal/

fails, though other machines reach it fine. Last week the team moved its
DNS server for `shop.internal`. The new one runs on this machine (dnsmasq).

Fix name resolution on this machine so that `curl http://api.shop.internal/`
answers `shop api: ok`, and every other `shop.internal` name resolves too.

- Names must come from DNS. Don't put `shop.internal` names in `/etc/hosts`:
  the addresses change, and the hosts file won't follow.
- Don't change the DNS server itself (dnsmasq); it is correct.
