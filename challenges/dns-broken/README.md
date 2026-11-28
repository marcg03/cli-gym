# Answer: it's always DNS

```sh
getent hosts api.shop.internal         # 127.0.0.20: not what DNS should say
grep shop /etc/hosts                   # a stale workaround wins over DNS
sed -i '/shop\.internal/d' /etc/hosts  # remove it
cat /etc/resolv.conf                   # nameserver 127.0.0.4: the old server
ss -lunp | grep :53                    # dnsmasq listens on 127.0.0.5
dig @127.0.0.5 api.shop.internal       # the new server answers 127.0.0.10
sed -i 's/^nameserver .*/nameserver 127.0.0.5/' /etc/resolv.conf
curl http://api.shop.internal/         # shop api: ok
```

**Why it works**

- Programs don't ask DNS directly. They call the C library, which follows the
  `hosts:` line in `/etc/nsswitch.conf`, usually `files` first, then `dns`.
  So an entry in `/etc/hosts` wins, and DNS is never asked.
- `getent hosts <name>` resolves a name the same way programs do, through
  nsswitch. It is the tool to see what curl will get.
- `dig` and `host` skip nsswitch and `/etc/hosts`: they ask a DNS server
  directly, the one in `/etc/resolv.conf` or the one you give with `@server`.
  When `dig @server` works and `getent` doesn't, the fault is on this machine.
- `/etc/resolv.conf` lists the DNS servers to ask (`nameserver` lines). Nothing
  listens at 127.0.0.4 any more, so every DNS lookup failed.
- `ss -lunp` lists listening UDP sockets with their process, which shows where the
  DNS server really is. DNS uses port 53.

There were two faults, and either one alone keeps curl broken. Fixing only
resolv.conf leaves the stale hosts entry winning. Removing only the hosts entry
gives `Could not resolve host`, because DNS goes to the dead server.

**The traps**

- Correcting the address in `/etc/hosts` makes curl work for one name, and
  every other `shop.internal` name still fails. The next time the API moves,
  it breaks again, silently.
- `dig` working doesn't mean programs will work, because dig never reads
  `/etc/hosts`. Test with `getent hosts` or the program itself.
- `ping` and `curl` errors mix up the two: "Could not connect" after a
  name lookup can be a wrong address from the hosts file, not a dead server.

**Remember**

- Order of lookup: `/etc/nsswitch.conf`, then `/etc/hosts`, then the servers in
  `/etc/resolv.conf`.
- `getent hosts` for what programs see, `dig @server` for what DNS says.
- On many systems resolv.conf is generated (NetworkManager, systemd-resolved,
  resolvconf, or NixOS's `networking.nameservers`), so a hand edit is a quick fix.
  The lasting fix goes in whatever generates it.
