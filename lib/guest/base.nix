# Guest NixOS module shared by the microVM runner and the self-test VM.
# Hypervisor-specific settings live in ./microvm.nix.
{ id, seed, challenge }:
{ config, lib, pkgs, ... }:
let
  c = challenge;
  gym = pkgs.writeShellApplication {
    name = "gym";
    runtimeInputs = with pkgs; [ jq coreutils ];
    text = builtins.readFile ./gym-guest.sh;
    checkPhase = ""; # the script is bash-only on purpose; skip shellcheck strictness on probe snippets
  };
  probes = map (lib.filterAttrs (_: v: v != null)) c.checks;
in
{
  imports = [ c.machine ];

  config = {
      networking.hostName = "gym";
      system.stateVersion = "25.11";

      services.getty.autologinUser = "root";
      programs.bash.loginShellInit = "cd /root; gym task";

      documentation.enable = false;
      nix.enable = false;

      environment.systemPackages = [ gym ] ++ (with pkgs; [
        coreutils gnused gnugrep gawk findutils diffutils less vim nano
      ]);

      environment.etc = {
        "cligym/task.md".text = c.task;
        "cligym/answer.md".text = c.answer;
        "cligym/checks.json".text = builtins.toJSON probes;
        "cligym/meta.json".text = builtins.toJSON (c.meta // { inherit id seed; });
      };

      systemd.services.cligym-setup = {
        description = "Place challenge files into /root";
        wantedBy = [ "multi-user.target" ];
        before = [ "getty.target" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        script = lib.concatStrings (lib.mapAttrsToList (dest: src: ''
          mkdir -p "$(dirname /root/${dest})"
          cp -rL --no-preserve=mode ${src} /root/${dest}
        '') c.files);
      };
  };
}
