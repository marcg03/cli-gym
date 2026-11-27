# A simple sed drill. Everything is generated in Nix from the seed: no scripts.
{ seed, rng, pkgs, lib, ... }:
let
  newHost = rng.pick "host" [ "db01.internal" "pg-primary.lan" "10.20.0.15" "postgres.prod" "db.shop.local" ];
  sections = rng.sample "sections" (rng.int "n-sections" 3 5) [ "auth" "billing" "search" "mailer" "cart" "inventory" "reports" ];

  # Lines a section may contain. Decoys: cache_host = localhost must stay, and
  # "db_hostname" must not be touched by a sloppy regex.
  pool = s: [
    "db_host = localhost"
    "db_port = ${toString (rng.pick "port-${s}" [ 5432 5433 6432 ])}"
    "db_name = ${s}"
    "cache_host = localhost"
    "log_level = ${rng.pick "lvl-${s}" [ "info" "debug" "warn" ]}"
    "debug_sql = ${rng.pick "dbg-${s}" [ "true" "false" ]}"
    "workers = ${toString (rng.int "workers-${s}" 1 16)}"
    "enable_debug_toolbar = yes"
    "db_hostname_check = strict"
    "timeout = ${toString (rng.int "timeout-${s}" 5 120)}"
  ];
  sectionLines = s:
    [ "[${s}]" ] ++ [ "db_host = localhost" ]
    ++ lib.filter (l: l != "db_host = localhost") (rng.sample "lines-${s}" (rng.int "n-${s}" 4 8) (pool s))
    ++ [ "" ];

  original = [ "# shopfront configuration" "" ] ++ lib.concatMap sectionLines sections;

  fix = l:
    if l == "db_host = localhost" then "db_host = ${newHost}"
    else if lib.hasInfix "debug" l then "# ${l}"
    else l;

  render = ls: lib.concatStringsSep "\n" ls + "\n";
in
{
  meta = {
    title = "Moving day for the database";
    difficulty = "easy";
    tags = [ "sed" ];
    minutes = 5;
  };

  files."app.conf" = pkgs.writeText "app.conf" (render original);

  task = ''
    The shop's database moved to `${newHost}`. Fix `/root/app.conf` in place:

    1. Every `db_host = localhost` line must become `db_host = ${newHost}`.
       Nothing else that mentions localhost may change.
    2. Disable debugging: comment out every line containing `debug` by putting
       `# ` (hash and a space) at the start of it.

    Don't change any other line. Try to do it with a single `sed` command.
  '';

  hints = [
    "`sed -i` edits a file in place. Try your expression without -i first to preview."
    "Anchor your match with ^ and $ so `cache_host` and `db_hostname_check` survive."
    "An address limits a command to matching lines: `/debug/s/^/# /`."
    "You can chain expressions: `sed -i -e '...' -e '...' app.conf`."
  ];

  checks = [
    {
      type = "command";
      description = "app.conf still exists";
      run = "test -f app.conf";
    }
    {
      type = "command";
      description = "db_host points at the new server";
      run = "grep -c '^db_host = ${newHost}$' app.conf";
      stdout = toString (builtins.length sections);
      feedback = "Expected ${toString (builtins.length sections)} db_host lines with the new host.";
    }
    {
      type = "command";
      description = "No uncommented line mentions debug";
      run = "grep -v '^# ' app.conf | grep -c debug";
      exitCode = 1;
      stdout = "0";
    }
    {
      type = "file";
      description = "Nothing else changed";
      path = "app.conf";
      sha256 = builtins.hashString "sha256" (render (map fix original));
      feedback = "Close! Something else changed too. Compare with your preview, e.g. did cache_host or db_hostname_check change?";
    }
  ];

  solution = ''
    sed -i -e 's/^db_host = localhost$/db_host = ${newHost}/' -e '/debug/s/^/# /' app.conf
  '';
}
