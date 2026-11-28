# Answer: the disk that will not empty

```sh
lsof +L1                    # open files with no name left on disk
: > /proc/<PID>/fd/<FD>     # empty the file the service still holds
```

For example, if `lsof +L1` shows `ledger <PID> ... 3w ... /var/log/ledger/ledger.log.1 (deleted)`,
the FD column `3w` means file descriptor 3, open for writing.

**Why it works**

- A file's space is freed when its last name is gone *and* no process has it open.
  `rm` only removes the name. The ledger service still writes to the file, so
  `df` (which asks the filesystem) counts it, and `du` (which walks the names) does not.
  A big gap between `df` and `du` is the tell.
- `lsof +L1` lists open files with fewer than one link, that is deleted but still open.
  Without lsof: `ls -l /proc/*/fd 2>/dev/null | grep deleted`.
- `/proc/<PID>/fd/<FD>` is a handle on that exact open file, even without a name.
  `: >` opens it with truncation, so the file becomes empty and its blocks are freed,
  while the service keeps writing to it.
- The service opened its log with `>>` (append), so its next write goes to the start
  of the now empty file. A process writing without append would continue at its old
  offset and leave a sparse file, which still frees the space but looks huge in `ls`.

**Another fix**

Many daemons reopen their log files on SIGHUP. This one does: `systemctl reload ledger`
(or `kill -HUP <PID>`) makes it close the deleted file and open a fresh `ledger.log`,
and the space comes back. It's the cleaner fix when the program supports it, so check
`systemctl cat <unit>` for an `ExecReload=` line.

**The traps**

- `systemctl restart ledger` frees the space too, but it interrupts the service.
- `> /var/log/ledger/ledger.log` empties the new, unused log, not the deleted one.
- Deleting more files changes nothing while the space is held by an open file.

**Remember**

- `df` much bigger than `du`: look for deleted but open files with `lsof +L1`.
- Truncate (`: > file`), don't `rm`, a log a process still writes to.
- The root cause was log rotation that renamed the file without telling the service.
  logrotate fixes that with `postrotate` (send SIGHUP) or `copytruncate`.
