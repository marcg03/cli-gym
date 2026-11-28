# A challenge is a folder challenges/<id>/ whose default.nix returns:
#   { title, task, answer, check, solution, files ? [ ], machine ? { } }
# task/answer are markdown files, check is an executable (exit 0 = solved),
# solution is a shell script, files are copied into /root, machine is extra NixOS config.
{ lib, pkgs, nixpkgs, microvm, challengeDir }:
let
  ids = lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir challengeDir));
  load = id: import (challengeDir + "/${id}");

  # NixOS config shared by the playable microVM and the self-test VM.
  guest = id:
    let c = load id;
    in {
      imports = [ (c.machine or { }) ];
      networking.hostName = "gym";
      system.stateVersion = "25.11";
      documentation.enable = false;
      nix.enable = false;

      services.getty.autologinUser = "root";
      programs.bash.loginShellInit = "cd /root; gym task";

      environment.systemPackages = with pkgs; [
        (writeShellApplication {
          name = "gym";
          runtimeInputs = [ coreutils ];
          checkPhase = "";
          text = ''
            TITLE=${lib.escapeShellArg c.title}
            TASK=${c.task} ANSWER=${c.answer} CHECK=${c.check} CHALLENGE=${challengeDir + "/${id}"}
          '' + builtins.readFile ./gym.sh;
        })
        coreutils gnused gnugrep gawk findutils diffutils less vim nano
      ];

      # Fresh copy of the starting files on every boot (/ is a tmpfs in the microVM).
      systemd.services.gym-setup = {
        wantedBy = [ "multi-user.target" ];
        before = [ "getty.target" ];
        serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
        # Starts with mkdir so the script is never empty (systemd refuses a unit without ExecStart).
        script = "mkdir -p /root\n" + lib.concatMapStrings (f: ''
          cp --no-preserve=mode ${f} /root/${baseNameOf f}
        '') (c.files or [ ]);
      };
    };

  # `nix run .#<id>`: boots the challenge in a qemu microVM on your terminal.
  vm = id:
    let
      runner = (nixpkgs.lib.nixosSystem {
        system = pkgs.stdenv.hostPlatform.system;
        modules = [
          microvm.nixosModules.microvm
          (guest id)
          {
            microvm = {
              hypervisor = "qemu";
              mem = 512;
              vcpu = 1;
              interfaces = [ ];
              socket = null;
              shares = [{ proto = "9p"; tag = "ro-store"; source = "/nix/store"; mountPoint = "/nix/.ro-store"; }];
            };
          }
        ];
      }).config.microvm.declaredRunner;
    in runner // { meta = (runner.meta or { }) // { mainProgram = "microvm-run"; }; };

  # `nix flake check`: the untouched world fails the check, the solution passes it.
  test = id: pkgs.testers.runNixOSTest {
    name = id;
    nodes.machine.imports = [ (guest id) ];
    testScript = ''
      machine.wait_for_unit("gym-setup.service")
      print(machine.fail("gym check"))
      machine.succeed("cd /root && bash ${(load id).solution}")
      print(machine.succeed("gym check"))
    '';
  };
in
{
  vms = lib.genAttrs ids vm;
  tests = lib.genAttrs ids test;
  shell = pkgs.mkShell { packages = [ pkgs.bashInteractive ]; };
}
