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
gym answer   # flip the card: the explained solution
gym check    # run the verifier
poweroff     # leave
```

Needs Linux with KVM (`/dev/kvm`). Check with `ls -l /dev/kvm`. If it's missing, enable
VT-x/AMD-V in the firmware and load `kvm-intel`/`kvm-amd` (NixOS: `boot.kernelModules`).
Without KVM, `gym start` falls back to emulation (slow), and `nix flake check` will time out:
NixOS advertises the `kvm` system feature even when `/dev/kvm` is absent.

## Layout

```
flake.nix
lib/options.nix          challenge schema (meta, task, answer, files, machine, checks, solution)
lib/rand.nix             pure seeded PRNG: rng.int / pick / sample / shuffle
lib/default.nix          evalChallenge, microVM runner, self-test
lib/guest/base.nix       guest NixOS module (autologin, files, in-VM gym)
lib/guest/gym-guest.sh   in-VM gym: task, check (the verifier), answer
lib/guest/microvm.nix    qemu microVM, 512 MiB, no network, host store via 9p
challenges/<id>/default.nix
gym/                     host CLI
```

## Writing a challenge

A challenge is a module receiving `{ seed, rng, pkgs, lib, ... }`. See
`challenges/sed-fix-config/`. Like an Anki card, the front is `task` and the back is
`answer`: a README.md in the challenge directory that explains the solution. Seeded
values are filled into it with `{{name}}` placeholders. The verifier runs `checks` in order. Each probe is
either a `command` (exit code and optional stdout) or a `file` (sha256), and
the first failure prints its `feedback`.

`nix flake check` boots every fixed seed in the NixOS test driver. There it asserts
that `gym check` fails on the untouched world and passes after `solution`.

## `gym check` output

The runner owns the format, so every challenge reports the same way. Challenge
authors only declare `checks`. Checks run in order and stop at the first failure:

```
PASS all 5 checks
```

```
FAIL check 4/5: Existing comments weren't commented again
  command: grep -c '^# #' app.conf
  expected: exit 1, output "0"
  got:      exit 0, output "1"
  note:     Some lines now start with '# #'. ...
```

`note` is the check's optional `feedback`. The exit status is 0 on pass and 1 on fail.

