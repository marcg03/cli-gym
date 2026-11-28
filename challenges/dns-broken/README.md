# Answer: it's always DNS

Based on the SadServers scenario "Jakarta": it's always DNS.

```sh
ping -c 1 api.shop.internal        # Name or service not known
cat /etc/hosts                     # nothing wrong
cat /etc/resolv.conf               # nameserver 127.0.0.5
dig api.shop.internal              # answers 127.0.0.10: DNS works
getent hosts api.shop.internal     # nothing: programs don't get the answer
cat /etc/nsswitch.conf             # hosts:     files    <- dns is missing
sed -i 's/^hosts:.*/hosts:     files dns/' /etc/nsswitch.conf
ping -c 1 api.shop.internal        # PING api.shop.internal (127.0.0.10)
```

**Why it works**

- Programs don't talk to DNS themselves. They call the C library, and its
  `hosts:` line in `/etc/nsswitch.conf` lists where to look for names, in order.
  `files` is `/etc/hosts`, `dns` means the servers in `/etc/resolv.conf`.
  With only `files`, DNS is never asked, and every name not in `/etc/hosts` fails.
- `dig`, `host` and `nslookup` skip that path: they send DNS queries straight to
  the server in `/etc/resolv.conf`. So "dig works, ping doesn't" points away from
  the network and the DNS server, and at this machine's lookup configuration.
- `getent hosts <name>` resolves a name exactly the way programs do, through
  nsswitch. It's the tool to compare with `dig`.
- The C library reads nsswitch.conf again when it changes, so new programs pick
  up the fix with no restart.

**The traps**

- Adding the name to `/etc/hosts` makes ping work for one name, and every other
  name still fails.
- Restarting the DNS server, or editing resolv.conf, changes nothing: they were
  never the problem. Check each layer before changing it.
- On other systems the line is longer, for example
  `hosts: files mymachines resolve [!UNAVAIL=return] myhostname dns` on systemd
  distributions. The order matters: the first source with an answer wins.

**Remember**

- Lookup path: `/etc/nsswitch.conf` decides, `/etc/hosts` is `files`,
  `/etc/resolv.conf` is `dns`.
- `dig` works but `getent hosts` doesn't: look at nsswitch.conf and /etc/hosts.
- Both fail: look at resolv.conf and the DNS server.
