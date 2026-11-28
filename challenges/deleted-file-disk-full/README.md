# Answer: the disk that will not empty

```sh
lsof +L1                                   # find it: ledger <PID> ... 3w ... ledger.log.1 (deleted)
exec 9< /proc/<PID>/fd/3                   # hold the deleted file open ourselves
systemctl reload ledger                    # ledger lets go and opens a fresh ledger.log
cat <&9 > /root/ledger.log.1               # copy it out (give the reload a second first)
exec 9<&-                                  # last handle closed: the space is freed
```

**Why it works**

- A file's space is freed when its last name is gone *and* no process has it open.
  `rm` only removes the name. The ledger service still writes to the file, so
  `df` (which asks the filesystem) counts it, and `du` (which walks the names) does not.
  A big gap between `df` and `du` is the tell.
- `lsof +L1` lists open files with fewer than one link, that is deleted but still open.
  The FD column `3w` means file descriptor 3, open for writing.
  Without lsof: `ls -l /proc/*/fd 2>/dev/null | grep deleted`.
- `/proc/<PID>/fd/<FD>` is a handle on that exact open file, even without a name.
  You can read it (`cp`, `cat`), or open it yourself.
- `exec 9< file` opens the file as descriptor 9 of *your* shell. Now two processes
  hold it, so it survives when ledger lets go.
- Many daemons reopen their logs on SIGHUP, and this one does: `systemctl reload ledger`
  (see `ExecReload=` in `systemctl cat ledger`). After that nothing writes to the old
  file, so the copy is complete. Closing descriptor 9 drops the last handle, and the
  kernel frees the space.
- The copy has to go to another filesystem: while it's being written, the old file
  still takes its space, and the volume has no room for a second copy.

**A simpler way**

```sh
cp /proc/<PID>/fd/3 /root/ledger.log.1     # copy while ledger keeps writing
: > /proc/<PID>/fd/3                       # then empty the file in place
```

`: >` opens the file with truncation, so its blocks are freed while ledger keeps writing
to it. Anything ledger writes between the `cp` and the truncate is lost, which is why the
reload way is better when the program supports it. Because ledger opened its log with
`>>` (append), its next write goes to the start of the empty file. A process writing
without append would continue at its old offset and leave a sparse file.

**The traps**

- Truncating or reloading first frees the space, and the old log is gone for good.
  Rescue first, free second.
- `systemctl restart ledger` frees the space too, but it interrupts the service.
- `> /var/log/ledger/ledger.log` empties the new, unused log, not the deleted one.
- Deleting more files changes nothing while the space is held by an open file.

**Remember**

- `df` much bigger than `du`: look for deleted but open files with `lsof +L1`.
- `/proc/<PID>/fd/<FD>` gets you a deleted file back, as long as something holds it open.
- Truncate (`: > file`), don't `rm`, a log a process still writes to.
- The root cause was log rotation that renamed the file without telling the service.
  logrotate fixes that with `postrotate` (send SIGHUP) or `copytruncate`.
