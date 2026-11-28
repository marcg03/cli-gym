# cli-gym

A LeetCode for the Linux command line. Each challenge is a small NixOS microVM with
something to fix or find. You solve it inside the VM with ordinary tools, and
`gym check` tells you whether you got it.

## Requirements

- Linux with Nix and flakes enabled.
- KVM (`ls -l /dev/kvm`). Without it the VM runs emulated and is very slow.

## Play

```sh
nix run .#sed-fix-config
```

Challenges:

```
sed-fix-config           easy    edit a config file with one sed command
deleted-file-disk-full   medium  rescue a deleted, still open log and free its disk
out-of-inodes            medium  No space left on device, but df -h shows room
dns-broken               medium  a hostname stopped resolving: hosts, resolv.conf, dig
```

You are logged in as root in `/root`, and the task is shown on login:

```
gym task     # show the task again
gym check    # run the challenge's check
gym answer   # flip the card: the explained solution
poweroff     # leave
```

Every boot starts from a fresh copy of the challenge, so you can always try again.

## Add a challenge

Make a folder `challenges/<id>/`. It is picked up automatically, and `<id>` is the name
you pass to `nix run .#<id>`.

```
challenges/<id>/
  default.nix    the challenge definition
  task.md        what the player sees: the front of the card
  README.md      the answer and why it works: the back of the card
  check.sh       decides whether the challenge is solved
  solution.sh    a reference solution, used by the self-test
  ...            optional: starting files, a machine.nix, data the check needs
```

`default.nix` is a plain attribute set:

```nix
{
  title = "Moving day for the database";
  difficulty = "easy";            # easy, medium or hard
  task = ./task.md;
  answer = ./README.md;
  check = ./check.sh;
  solution = ./solution.sh;
  files = [ ./app.conf ];         # optional: copied into /root at boot
  machine = import ./machine.nix; # optional: extra NixOS config (services, mounts, packages)
}
```

`files` suits challenges about editing files. `machine` is a NixOS module and suits
challenges about a running system: a service to debug, a full disk, a broken mount.
See `challenges/deleted-file-disk-full/machine.nix` for an example.

### The check

`gym check` runs `check` as root in `/root`, with `$CHALLENGE` set to the challenge
folder, so the check can read files such as an `expected.conf`. It can be any
executable (commit it with the executable bit set).

- Exit 0 means solved, anything else means not yet.
- The check prints its own feedback. The runner only adds `PASS` or `FAIL (check exited N)`.
- On failure, say what was expected and what was found:

```
failed: existing comments should stay as they are
  expected: 0 lines starting with '# #'
  got:      3 (the header was already a comment)

FAIL (check exited 1)
```

### The answer

`README.md` is the back of the card, shown by `gym answer`. Give the solution first,
then explain why it works, the traps a player is likely to fall into, and a few
things to remember.

### Test it

`nix flake check` boots every challenge in the NixOS test driver and asserts that the
check fails on the untouched challenge and passes after `solution.sh`. To test one
challenge:

```sh
nix build .#checks.x86_64-linux.<id> -L
```

Then play it once with `nix run .#<id>`.

## Layout

```
flake.nix          outputs: packages.<id> (the VM), checks.<id> (the self-test)
lib/default.nix    challenge loader, guest NixOS config, microVM, self-test
lib/gym.sh         the in-VM gym command
challenges/<id>/   one folder per challenge
```
