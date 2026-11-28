# Answer: Hammered

Based on the CyberDefenders lab "Hammered" (from The Honeynet Project). The logs
here are new, made-up data with the same story and the same twelve questions.

```
1: ssh
2: 5.15.0-97-generic
3: root
4: 5
5: 198.51.100.73
6: 1292
7: 4
8: nmap
9: 03/21/2024 11:42:07 PM
10: 3
11: systemd-net
12: proxyprobe/2.4
```

**How to find them** (in `/root/evidence`)

```sh
grep -c 'Failed password' auth.log                    # 1. thousands of failed sshd logins
head -n 1 dmesg                                       # 2. Linux version 5.15.0-97-generic
grep 'Accepted' auth.log | awk '{print $9}' | sort | uniq -c   # 3. password logins as root
grep 'Accepted password for root' auth.log \
  | awk '{print $11}' | sort | uniq -c | sort -rn     # 4. five IPs; 5. the top one, 9 logins
wc -l < apache2/www-access.log                        # 6. one line per request
grep 'COMMAND=.*iptables' auth.log                    # 7. who ran what
grep ' install ' dpkg.log                             # 8. packages, with full dates
grep "Accepted password for root from 198.51.100.73" auth.log | tail -n 1   # 9.
grep -i warning daemon.log                            # 10. the debian-start warning
grep 'new user' auth.log                              # 11. two accounts, one is dana's
grep '"GET http' apache2/www-access.log | awk -F'"' '{print $6}' | sort -u  # 12.
```

**Why, question by question**

- 1, 3: auth.log shows a brute force against sshd: thousands of `Failed password`
  lines from many addresses, then `Accepted password for root`. dana's own logins
  say `Accepted publickey for dana`.
- 2: the kernel prints its version first thing at boot; `dmesg` and `kern.log` keep it.
  The gcc version in the same line is not the kernel's.
- 4, 5: only addresses with an `Accepted password for root` line got in. The address
  with the most failures, 203.0.113.200, never did, and 192.168.1.20 is dana. Counting
  all `Accepted` lines, or all `Failed` lines, gives the wrong answers.
- 7: six `iptables -A` lines exist. dana added two (ports 80 and 443) from her own
  account. The other four came from the backdoor account. `-L` lists rules and `-D`
  deletes one: neither adds.
- 8: the attacker installed nmap with `sudo apt-get install` from the backdoor
  account; dpkg.log has it at the same minute, along with nmap's libraries.
- 9: syslog lines have no year. dpkg.log has full dates, which gives 2024. Then
  convert 23:42:07 to 11:42:07 PM. The attacker's later login as `systemd-net` is
  not a login to root.
- 10: MySQL's own `[Warning]` lines are routine. The Debian start script's
  `mysql.user contains 3 root accounts without password!` means anyone on the box
  can be database root.
- 11: dana created `deploy` from her session on Mar 5. `systemd-net` was created
  minutes after the first break-in from 198.51.100.73, added to `sudo`, and named
  to look like a system account.
- 12: an open-proxy scanner asks the server for other sites by full URL
  (`GET http://www.example.com/`) and tries `CONNECT`. Nikto and zgrab are
  vulnerability scanners, not proxy testers.

**Remember**

- `grep | awk '{print $N}' | sort | uniq -c | sort -rn` is the workhorse: count
  anything by any field.
- Attribute before you count: which account, which session, which source address.
- syslog timestamps have no year and use the server's clock; find the year elsewhere.
- Attackers hide in plain sight: names like `systemd-net`, rules mixed in with the
  admin's.
