# Answer: moving day for the database

```sh
sed -i -e 's/^db_host = localhost$/db_host = db01.internal/' -e '/^#/!s/.*debug.*/# &/' app.conf
```

**Why it works**

- `-i` edits `app.conf` in place. Leave it off to preview the result on stdout first.
- `-e` adds an expression. Several `-e`s run in order on every line.
- `s/^db_host = localhost$/db_host = db01.internal/` substitutes on lines matching
  exactly `db_host = localhost`. `^` and `$` anchor the start and end of the line, so
  `cache_host = localhost` and `db_hostname_check = strict` are left alone.
- `/^#/!s/.*debug.*/# &/` combines an **address** and a command:
  - `/^#/` selects lines starting with `#`, and `!` negates it, so the command only runs
    on lines that are *not* already comments.
  - `s/.*debug.*/# &/` matches the whole line if it contains `debug`, and `&` puts the
    matched text back after `# `.

**The trap**

`sed 's/\(.*debug.*\)/# \1/'` looks right, but it also hits
`# set log_level = debug when troubleshooting`, which turns into `# # set ...`.
Always ask "what else does my pattern match?", including comments.

**Remember**

- `sed '/PATTERN/ COMMAND'` limits a command to matching lines, and `/PATTERN/!` to the
  non-matching ones.
- `&` in the replacement is the whole match.
- Anchor with `^...$` whenever a pattern could also match a longer line.
