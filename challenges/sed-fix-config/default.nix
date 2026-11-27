# A simple sed drill. Everything is generated in Nix from the seed: no scripts.
{ seed, rng, pkgs, lib, ... }:
let
  newHost = rng.pick "host" [ "db01.internal" "pg-primary.lan" "10.20.0.15" "postgres.prod" "db.shop.local" ];
  sections = rng.sample "sections" (rng.int "n-sections" 3 5) [ "auth" "billing" "search" "mailer" "cart" "inventory" "reports" ];

  # Lines a section may contain. Decoys: cache_host = localhost must stay,
  # "db_hostname" must not be touched by a sloppy regex, and already-commented
  # debug lines must not get commented twice.
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
    "# debug_profiler = on"
  ];
  sectionLines = s:
    [ "[${s}]" ] ++ [ "db_host = localhost" ]
    ++ lib.filter (l: l != "db_host = localhost") (rng.sample "lines-${s}" (rng.int "n-${s}" 4 8) (pool s))
    ++ [ "" ];

  # The header always has one commented line mentioning debug.
  original = [ "# shopfront configuration" "# set log_level = debug when troubleshooting" "" ] ++ lib.concatMap sectionLines sections;

  fix = l:
    if lib.hasPrefix "#" l then l
    else if l == "db_host = localhost" then "db_host = ${newHost}"
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
       `# ` (hash and a space) at the start of it. Lines that are already
       comments stay exactly as they are.

    Don't change any other line. Try to do it with a single `sed` command.
  '';

  # The back of the card, with the seeded host filled in.
  answer = builtins.replaceStrings [ "{{host}}" ] [ newHost ] (builtins.readFile ./README.md);

  # Any executable works here. It runs in /root, prints its own feedback, exit 0 = solved.
  check = pkgs.writeShellScript "check-sed-fix-config" ''
    fail() { echo "failed: $1"; shift; for l in "$@"; do echo "  $l"; done; exit 1; }

    [ -f app.conf ] || fail "app.conf is missing"

    got=$(grep -c '^db_host = ${newHost}$' app.conf)
    [ "$got" = ${toString (builtins.length sections)} ] || fail "db_host should point at the new server" \
      "expected: ${toString (builtins.length sections)} lines 'db_host = ${newHost}'" "got:      $got"

    got=$(grep -v '^#' app.conf | grep -c debug)
    [ "$got" = 0 ] || fail "every uncommented line with debug should be commented out" \
      "expected: 0 uncommented debug lines" "got:      $got"

    got=$(grep -c '^# #' app.conf)
    [ "$got" = 0 ] || fail "existing comments should stay as they are" \
      "expected: 0 lines starting with '# #'" "got:      $got (the header was already a comment)"

    diff -q ${pkgs.writeText "expected-app.conf" (render (map fix original))} app.conf > /dev/null \
      || fail "nothing else should change" "hint: compare with your preview. Did cache_host or db_hostname_check change?"

    echo "app.conf looks right"
  '';

  solution = ''
    sed -i -e 's/^db_host = localhost$/db_host = ${newHost}/' -e '/^#/!s/.*debug.*/# &/' app.conf
  '';
}
