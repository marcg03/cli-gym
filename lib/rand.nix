# A tiny pure PRNG: every draw is a hash of (challenge id, seed, draw name).
# Naming each draw keeps results stable when a challenge adds new draws.
{ lib }:
id: seed:
let
  raw = name: lib.fromHexString (builtins.substring 0 12 (builtins.hashString "sha256" "${id}:${toString seed}:${name}"));
in
rec {
  # Integer in [lo, hi] (inclusive).
  int = name: lo: hi: lo + lib.mod (raw name) (hi - lo + 1);
  # One element of a list.
  pick = name: xs: builtins.elemAt xs (int name 0 (builtins.length xs - 1));
  # Deterministic permutation.
  shuffle = name: xs:
    map (e: e.v) (builtins.sort (a: b: a.k < b.k) (lib.imap0 (i: v: { k = raw "${name}/${toString i}"; inherit v; }) xs));
  # n distinct elements.
  sample = name: n: xs: lib.take n (shuffle name xs);
  # Bernoulli with probability num/den.
  chance = name: num: den: int name 1 den <= num;
}
