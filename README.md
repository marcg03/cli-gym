# cli-gym

A LeetCode for the Linux command line. Each challenge is a NixOS microVM built
from Nix code and a seed. You solve it inside the VM and `gym check` verifies it.

## Try it

```sh
nix run .#sed-fix-config        # seed 1
nix run .#sed-fix-config-s3     # seeds 1-5 are plain flake outputs
nix develop -c gym list
nix develop -c gym start sed-fix-config 4242   # any seed (uses --impure --expr)
```

Inside the VM (you're logged in as root in /root):

```
gym task     # show the task again
gym hint     # next hint
gym check    # run the verifier
poweroff     # leave
```

Needs Linux with KVM (`/dev/kvm`). Without it, `gym start` falls back to emulation (slow).

## Layout

```
flake.nix
lib/options.nix          challenge schema (meta, task, hints, files, machine, checks, solution)
lib/rand.nix             pure seeded PRNG: rng.int / pick / sample / shuffle
lib/default.nix          evalChallenge, microVM runner, self-test
lib/guest/base.nix       guest NixOS module (autologin, files, in-VM gym)
lib/guest/gym-guest.sh   in-VM gym: task, hint, check (the verifier)
lib/guest/microvm.nix    qemu microVM, 512 MiB, no network, host store via 9p
challenges/<id>/default.nix
gym/                     host CLI
```

## Writing a challenge

A challenge is a module receiving `{ seed, rng, pkgs, lib, ... }`. See
`challenges/sed-fix-config/default.nix`. The verifier runs `checks` in order. Each probe is
either a `command` (exit code and optional stdout) or a `file` (sha256), and
the first failure prints its `feedback`.

`nix flake check` boots every fixed seed in the NixOS test driver. There it asserts
that `gym check` fails on the untouched world and passes after `solution`.
