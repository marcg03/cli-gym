# The challenge schema. Each challenges/<id>/default.nix is a module against these options.
# It receives { seed, rng, pkgs, lib } as module arguments.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options = {
    meta = {
      title = mkOption { type = types.str; };
      difficulty = mkOption { type = types.enum [ "easy" "medium" "hard" ]; default = "easy"; };
      tags = mkOption { type = types.listOf types.str; default = [ ]; };
      minutes = mkOption { type = types.int; default = 10; description = "Rough time estimate."; };
    };
    task = mkOption { type = types.lines; description = "Markdown shown to the player. Can use seeded values."; };
    answer = mkOption {
      type = types.lines;
      description = "The back of the card: a short markdown README explaining the solution. Shown by `gym answer`.";
    };
    files = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Files copied (writable) into /root at boot: { \"app.conf\" = pkgs.writeText ...; }";
    };
    machine = mkOption {
      type = types.deferredModule;
      default = { };
      description = "NixOS module for the guest: services, faults, packages.";
    };
    check = mkOption {
      type = types.path;
      description = ''
        Any executable (shell, Python, a compiled binary, ...), e.g. pkgs.writeShellScript.
        `gym check` runs it as root in /root. Exit 0 = solved, anything else = not yet.
        It prints its own feedback.
      '';
    };
    solution = mkOption { type = types.lines; description = "Reference solution (shell, run as root in /root). Used by self-tests."; };
  };
}
