# cli-gym

A LeetCode for the Linux command line. Each challenge is a NixOS microVM built
from Nix code and a seed. You solve it inside the VM and `gym check` verifies it.

## Try it

```sh
nix run .#sed-fix-config                            # the default world (seed 0)
GYM_SEED=42 nix run --impure .#sed-fix-config       # another world
nix develop -c gym list
nix develop -c gym start sed-fix-config 42          # same as the GYM_SEED line
```

Without `--impure`, `GYM_SEED` is ignored and you get the default seed. The VM prints the
seed it was built with when you log in, so you can always tell.

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
lib/options.nix          challenge schema (meta, task, answer, check, solution, files, machine)
lib/rand.nix             pure seeded PRNG: rng.int / pick / sample / shuffle
lib/default.nix          evalChallenge, microVM runner, self-test
lib/guest/base.nix       guest NixOS module (autologin, files, in-VM gym)
lib/guest/gym-guest.sh   in-VM gym: task, check (runs the challenge check), answer
lib/guest/microvm.nix    qemu microVM, 512 MiB, no network, host store via 9p
challenges/<id>/default.nix
gym/                     host CLI
```

## Writing a challenge

Make a folder `challenges/<id>/` with a `default.nix`. It is picked up automatically.
The module receives `{ seed, rng, pkgs, lib, ... }` and sets:

| field      | required | what it is |
|------------|----------|------------|
| `meta.title` (+ `difficulty`, `tags`, `minutes`) | title only | shown by `gym list` and `gym task` |
| `task`     | yes | markdown, the front of the card |
| `answer`   | yes | markdown, the back of the card (`gym answer`). Can be read from a README.md |
| `check`    | yes | any executable: shell, Python, C++, ... e.g. `pkgs.writeShellScript` |
| `solution` | yes | reference solution (shell), used by the self-tests |
| `files`    | no  | files copied into `/root` at boot, e.g. `{ "app.conf" = pkgs.writeText ...; }` |
| `machine`  | no  | extra NixOS config for the VM: services, users, packages, broken things |

See `challenges/sed-fix-config/`. Use `rng.int`, `rng.pick`, `rng.sample` and `rng.shuffle`
for anything seeded, and interpolate the values into `task`, `check` and `solution`.

## The check contract

`gym check` runs your `check` as root in `/root`. **Exit 0 means solved**, and anything
else means not yet. The check prints its own feedback, and the runner only adds a final
`PASS` or `FAIL (check exited N)` line. A good check says what it expected and what it got:

```
failed: existing comments should stay as they are
  expected: 0 lines starting with '# #'
  got:      3 (the header was already a comment)

FAIL (check exited 1)
```

`nix flake check` boots the default seed and two extra seeds in the NixOS test driver.
There it asserts that the check fails on the untouched world and passes after `solution`.
