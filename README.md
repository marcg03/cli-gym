# cli-gym

A LeetCode for the Linux command line. Each challenge is a small NixOS microVM.
You solve it inside the VM and `gym check` tells you whether you got it.

## Play

```sh
nix run .#sed-fix-config
```

Challenges:

```
sed-fix-config           easy    edit a config file with one sed command
deleted-file-disk-full   medium  free a full disk held by a deleted, still open log
```

You're logged in as root in `/root`:

```
gym task     # show the task again
gym check    # run the challenge's check
gym answer   # flip the card: the explained solution
poweroff     # leave
```

Needs Linux with KVM (`ls -l /dev/kvm`). Without it the VM runs emulated and is very slow.

## Write a challenge

Make a folder `challenges/<id>/`. It's picked up automatically. Its `default.nix` is a
plain attribute set:

```nix
{
  title = "Moving day for the database";
  difficulty = "easy";
  task = ./task.md;          # front of the card
  answer = ./README.md;      # back of the card
  check = ./check.sh;        # any executable: exit 0 = solved
  solution = ./solution.sh;  # reference solution, used by nix flake check
  files = [ ./app.conf ];    # optional: copied into /root at boot
  # machine = { ... };       # optional: extra NixOS config (services, users, packages)
}
```

### The check contract

`gym check` runs `check` as root in `/root`, with `$CHALLENGE` pointing at the
challenge folder (e.g. for an `expected.conf`). **Exit 0 means solved.** The check
prints its own feedback, and the runner only adds `PASS` or `FAIL (check exited N)`.
Say what you expected and what you got:

```
failed: existing comments should stay as they are
  expected: 0 lines starting with '# #'
  got:      3 (the header was already a comment)

FAIL (check exited 1)
```

### Self-test

`nix flake check` boots each challenge in the NixOS test driver. It asserts that the check
fails on the untouched files and passes after `solution`.

## Layout

```
flake.nix          outputs: packages.<id> (the VM), checks.<id> (the self-test)
lib/default.nix    challenge loader, guest config, microVM, self-test
lib/gym.sh         the in-VM gym command
challenges/<id>/   one folder per challenge
```
