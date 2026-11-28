The shop's database moved to `db01.internal`. Fix `/root/app.conf` in place:

1. Every `db_host = localhost` line must become `db_host = db01.internal`.
   Nothing else that mentions localhost may change.
2. Disable debugging: comment out every line containing `debug` by putting
   `# ` (hash and a space) at the start of it. Lines that are already
   comments stay exactly as they are.

Don't change any other line. Try to do it with a single `sed` command.
