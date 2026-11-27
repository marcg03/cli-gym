# Host-side gym: list challenges and boot one.
flake=${CLIGYM_FLAKE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}

usage() {
  cat >&2 <<'USAGE'
gym list                  show challenges
gym start <id> [seed]     boot a challenge VM (default seed unless one is given)
USAGE
  exit 2
}

cmd_list() {
  nix eval --json "$flake#lib.catalog" | jq -r '
    to_entries[] | [.key, .value.difficulty, "\(.value.minutes)m", (.value.tags | join(",")), .value.title] | @tsv' \
  | column -t -s $'\t' -N ID,LEVEL,TIME,TAGS,TITLE
}

cmd_start() {
  local id=${1:?usage: gym start <id> [seed]}
  if [ -n "${2:-}" ]; then
    [[ $2 =~ ^[0-9]+$ ]] || { echo "seed must be a number" >&2; exit 2; }
    GYM_SEED=$2 exec nix run --impure "$flake#$id"
  fi
  exec nix run "$flake#$id"
}

case "${1:-}" in
  list) cmd_list ;;
  start) shift; cmd_start "$@" ;;
  *) usage ;;
esac
