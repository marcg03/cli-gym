# gym list                      show challenges
# gym start <id> [seed]         boot a challenge VM (seed defaults to 1)
# Env: CLIGYM_FLAKE (default: the git repo you're in), CLIGYM_KVM=0 to force emulation.

flake=${CLIGYM_FLAKE:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
system=$(nix eval --impure --raw --expr builtins.currentSystem)

kvm=true
if [ "${CLIGYM_KVM:-}" = 0 ] || [ ! -w /dev/kvm ]; then kvm=false; fi

usage() {
  cat >&2 <<'USAGE'
gym list                  show challenges
gym start <id> [seed]     boot a challenge VM (seed defaults to 1)
USAGE
  exit 2
}

cmd_list() {
  nix eval --json "$flake#catalog" | jq -r '
    to_entries[] | [.key, .value.difficulty, "\(.value.minutes)m", (.value.tags | join(",")), .value.title] | @tsv' \
  | column -t -s $'\t' -N ID,LEVEL,TIME,TAGS,TITLE
}

cmd_start() {
  local id=${1:?usage: gym start <id> [seed]} seed=${2:-1}
  [[ $seed =~ ^[0-9]+$ ]] || { echo "seed must be a number" >&2; exit 2; }
  echo "Booting $id, seed $seed$([ "$kvm" = false ] && echo ' (no KVM: emulated, slow)'). Leave with 'poweroff'."
  if [ "$kvm" = true ] && nix eval --json "$flake#fixedSeeds" | jq -e "index($seed)" > /dev/null; then
    # Pure, cacheable flake output.
    exec nix run "$flake#$id-s$seed"
  fi
  # Free-form seed (or no KVM): build from the same function via --expr.
  local ref="path:$flake"
  [ -d "$flake/.git" ] && ref="git+file://$flake"
  exec nix run --impure --expr "
    (builtins.getFlake \"$ref\").lib.$system.runWith { id = \"$id\"; seed = $seed; kvm = $kvm; }"
}

case "${1:-}" in
  list) cmd_list ;;
  start) shift; cmd_start "$@" ;;
  *) usage ;;
esac
