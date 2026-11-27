# Answer: moving day for the database

```sh
sed -i -e 's/^db_host = localhost$/db_host = {{host}}/' -e '/debug/s/^/# /' app.conf
```

**Why it works**

- `-i` edits `app.conf` in place. Leave it off to preview the result on stdout first.
- `-e` adds an expression. Several `-e`s run in order on every line.
- `s/^db_host = localhost$/db_host = {{host}}/` substitutes on lines matching
  exactly `db_host = localhost`. `^` and `$` anchor the start and end of the line, so
  `cache_host = localhost` and `db_hostname_check = strict` are left alone.
- `/debug/s/^/# /` is an **address** (`/debug/`) followed by a command. Only on lines
  containing `debug`, replace the empty start of the line (`^`) with `# `.

**Remember**

`sed '/PATTERN/ COMMAND'` limits a command to matching lines. Anchor with `^...$`
whenever a pattern could also match a longer line.
