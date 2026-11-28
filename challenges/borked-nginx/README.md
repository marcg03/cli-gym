# Answer: borked nginx

Based on the SadServers scenario "Cape Town": Borked Nginx.

```sh
systemctl status nginx              # failed: unexpected ";" in /etc/nginx/sites-enabled/default:1
nginx -t                            # same error, without starting anything
vim /etc/nginx/sites-enabled/default    # delete the lone ";" on line 1
nginx -t                            # test is successful
systemctl restart nginx
curl -Is 127.0.0.1:80 | head -1     # HTTP/1.1 500 Internal Server Error: not done yet
tail /var/log/nginx/error.log       # (24: Too many open files)
cat /proc/$(cat /run/nginx.pid)/limits | grep 'open files'   # 10
systemctl cat nginx                 # LimitNOFILE=10, in /run/systemd/system/nginx.service
vim /run/systemd/system/nginx.service   # delete the LimitNOFILE=10 line
systemctl daemon-reload
systemctl restart nginx
curl -Is 127.0.0.1:80 | head -1     # HTTP/1.1 200 OK
```

**Why it works**

- The unit runs `nginx -t` in `ExecStartPre=` before starting. A config error makes
  that step fail, so nginx never starts, and `systemctl status` shows nginx's own
  error message with the file and line. `nginx -t` gives the same check by hand.
- Once nginx runs, its errors go to its own log, `/var/log/nginx/error.log`, not
  to the journal. `24` is the error number for "too many open files" (EMFILE).
- Every connection, file, log and pipe a process has open is a file descriptor,
  and the kernel caps how many it may hold. `/proc/<PID>/limits` shows the cap of a
  running process. With 10, nginx can barely start a worker and can't open the page
  it should serve, so it answers 500.
- A shell's `ulimit -n` is not the limit a service gets. systemd sets it per
  service with `LimitNOFILE=` in the unit, and `systemctl cat` shows the unit and
  any drop-ins.
- After editing a unit file, `systemctl daemon-reload` makes systemd read it again.
  Without it the restart keeps the old limit (systemctl warns that the unit file
  changed on disk).

**The traps**

- Fixing the semicolon and stopping at "nginx is active": it runs, but every
  request fails. Test with curl after each fix.
- Restarting without `daemon-reload` after editing the unit: the limit stays 10.
- Starting nginx by hand (`nginx` in a shell) gets your shell's limit and works,
  but systemd doesn't manage it, and the next restart or reboot breaks it again.
- On NixOS `/etc/systemd/system` is read-only, so `systemctl edit nginx` fails.
  `systemctl edit --runtime nginx` writes a drop-in under `/run/systemd/system`,
  which also works here: `[Service]` then `LimitNOFILE=1024`.

**Remember**

- `systemctl status <unit>`, then `journalctl -u <unit>`, then the program's own log.
- `nginx -t` (and `apachectl configtest`, `sshd -t`) test a config before you restart.
- "Too many open files": compare `/proc/<PID>/limits` with the unit's `LimitNOFILE=`.
- Edit a unit, `daemon-reload`, restart.
