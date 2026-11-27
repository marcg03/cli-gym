{ lib, pkgs, system, nixpkgs, microvm, challengeDir }:
let
  # challenges/<id>/default.nix
  challengeFiles = lib.mapAttrs (name: _: challengeDir + "/${name}/default.nix")
    (lib.filterAttrs (_: t: t == "directory") (builtins.readDir challengeDir));

  # Evaluate a challenge module for one seed.
  evalChallenge = id: seed:
    (lib.evalModules {
      modules = [ ./options.nix challengeFiles.${id} ];
      specialArgs = {
        inherit seed pkgs;
        rng = import ./rand.nix { inherit lib; } id seed;
      };
    }).config;

  guestBase = id: seed: import ./guest/base.nix { inherit id seed; challenge = evalChallenge id seed; };

  nixos = { id, seed, kvm ? true }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        microvm.nixosModules.microvm
        (guestBase id seed)
        (import ./guest/microvm.nix { inherit kvm; })
      ];
    };

  # The thing you `nix run`: boots the challenge VM with its console on your terminal.
  run = id: seed:
    let vm = (nixos { inherit id seed; }).config.microvm.declaredRunner;
    in vm // { meta = (vm.meta or { }) // { mainProgram = "microvm-run"; }; };

  # Self-test: unsolved world must fail `gym check`, reference solution must pass it.
  selfTest = id: seed:
    let c = evalChallenge id seed;
    in pkgs.testers.runNixOSTest {
      name = "${id}-s${toString seed}";
      nodes.machine = {
        imports = [ (guestBase id seed) ];
        virtualisation.memorySize = 512;
      };
      testScript = ''
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("cligym-setup.service")
        print(machine.fail("gym check"))
        ${lib.concatMapStrings (w: ''
          machine.succeed("cd /root && bash ${pkgs.writeText "wrong.sh" w}")
          print(machine.fail("gym check"))
          machine.succeed("systemctl restart cligym-setup")
        '') c.wrongSolutions}
        machine.succeed("cd /root && bash ${pkgs.writeText "solution.sh" c.solution}")
        print(machine.succeed("gym check"))
        machine.succeed("gym answer -y | grep -q sed")
      '';
    };

  catalog = lib.mapAttrs (id: _:
    let c = evalChallenge id 0;
    in c.meta) challengeFiles;
in
{
  inherit challengeFiles evalChallenge nixos run selfTest catalog;
}
