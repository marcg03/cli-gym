Monitoring says the log volume `/var/log/ledger` is almost full. A colleague
already deleted the big rotated log, `ledger.log.1`, but `df` still shows the
volume nearly full, and `du` says the folder holds almost nothing.

Finance needs that log: it's the only record of yesterday's settlements.

1. Rescue the full contents of the deleted `ledger.log.1` to
   `/root/ledger.log.1` (on another filesystem).
2. Free the space so `/var/log/ledger` is under 50% used.

- The `ledger` service settles payments. It must keep running: don't stop,
  restart or kill it.
- The `audit-*.log` files are records we have to keep. Don't touch them.
