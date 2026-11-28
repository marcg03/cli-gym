# Answer: no space left, half the disk free

```sh
df -i /srv                                         # IUse% 100%: out of inodes, not of space
du --inodes -x /srv | sort -n | tail               # which folder holds the files
find /srv/shop/sessions -type f -mmin +1440 -delete  # delete sessions idle for over 24 hours
df -i /srv                                         # IUse% back to about 1%
```

**Why it works**

- A file needs two things: blocks for its data, and an inode for its metadata
  (owner, mode, times, where the blocks are). `df -h` counts blocks, `df -i` counts
  inodes. Either one running out gives the same error: `No space left on device`.
- Most filesystems get a fixed number of inodes when they are created (ext4 sets it
  at `mkfs` time). Lots of tiny or empty files use up the inodes long before the
  blocks. Empty files use no blocks at all, but each one still takes an inode.
- `du --inodes` counts files instead of bytes, so it points at the folder with the
  most of them. Without it: `find /srv -xdev -type f | cut -d/ -f1-4 | sort | uniq -c | sort -n`.
- `find -mmin +1440` matches files last modified more than 1440 minutes (24 hours)
  ago. `-mtime +0` does the same in whole days: find rounds the age down to days, and
  `+0` means "more than 0 full days". `-delete` removes them without starting
  a process per file.

**The traps**

- Deleting the big database dump frees 30 MiB of blocks but only one inode.
- `rm /srv/shop/sessions/*` fails with `Argument list too long`: the shell expands the
  `*` to some 60000 names, more than fits on one command line. It would also log out
  everyone still logged in. `find` doesn't need the list on its command line.
- `find ... -mmin +60` (an hour) also deletes live sessions. Read the rule: 24 hours.
- On tmpfs you could remount with a bigger `nr_inodes=`, but a real disk can't do that
  without reformatting, and the junk would fill it again.
- `ls` on the folder is slow and floods the screen. `ls -f | wc -l` or `find | wc -l`
  counts without sorting.

**Remember**

- `No space left on device` but `df -h` has room: run `df -i`.
- `du --inodes` finds where the files are, `find -mtime` / `-mmin` selects them by age,
  `-delete` removes them.
- Too many arguments for `rm`: use `find -delete`, or `find -print0 | xargs -0 rm`.
- The root cause was a shop that never expired its sessions. The fix is a cleanup job
  (a systemd timer, cron, or `systemd-tmpfiles` with an age, like `e /srv/shop/sessions - - - 1d`).
