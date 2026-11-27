# The challenge schema. Each challenges/<id>/default.nix is a module against these options.
# It receives { seed, rng, pkgs, lib } as module arguments.
{ lib, ... }:
let
  inherit (lib) mkOption types;
  probe = types.submodule {
    options = {
      type = mkOption {
        type = types.enum [ "file" "command" ];
        description = "file: compare a file's sha256; command: run a snippet and judge its exit code and stdout.";
      };
      description = mkOption { type = types.str; description = "Shown in the pass/fail list."; };
      feedback = mkOption { type = types.nullOr types.str; default = null; description = "Shown when this probe fails."; };
      # file
      path = mkOption { type = types.nullOr types.str; default = null; description = "Relative paths are relative to /root."; };
      sha256 = mkOption { type = types.nullOr types.str; default = null; description = "Expected sha256 of the file (or of command stdout)."; };
      sha256File = mkOption { type = types.nullOr types.str; default = null; description = "File containing the expected sha256 (for data generated at build time)."; };
      # command
      run = mkOption { type = types.nullOr types.str; default = null; description = "Shell snippet, run as root in /root."; };
      exitCode = mkOption { type = types.int; default = 0; };
      stdout = mkOption { type = types.nullOr types.str; default = null; description = "Expected stdout (trailing newlines stripped)."; };
    };
  };
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
    hints = mkOption { type = types.listOf types.str; default = [ ]; };
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
    checks = mkOption { type = types.listOf probe; description = "Probes run in order by `gym check`."; };
    solution = mkOption { type = types.lines; description = "Reference solution (shell, run as root in /root). Used by self-tests."; };
  };
}
