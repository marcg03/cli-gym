{
  description = "cli-gym: a LeetCode for the Linux command line, built on Nix and microVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    microvm = {
      url = "git+https://github.com/microvm-nix/microvm.nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      # spectrum is only needed for microvm.nix's graphics support; point it at
      # ourselves so it never gets fetched.
      inputs.spectrum.follows = "";
    };
  };

  outputs =
    { self, nixpkgs, microvm }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});

      # One deterministic seed by default. For another one, pass it impurely:
      #   GYM_SEED=42 nix run --impure .#sed-fix-config
      # (without --impure, getEnv returns "" and you get the default seed; the VM shows which.)
      defaultSeed = 0;
      seedEnv = builtins.getEnv "GYM_SEED";
      seed =
        if seedEnv == "" then defaultSeed
        else if builtins.match "[0-9]+" seedEnv != null then lib.toInt seedEnv
        else throw "GYM_SEED must be a number, got '${seedEnv}'";

      # Extra seeds the self-tests cover, so a challenge can't only work for one world.
      testSeeds = [ defaultSeed 1 2 ];

      gymFor = system: pkgs: import ./lib {
        inherit lib pkgs system nixpkgs microvm;
        challengeDir = ./challenges;
      };
    in
    {
      # lib.<system>.* -> builders; lib.catalog -> metadata for `gym list`
      lib = forAllSystems (system: pkgs: gymFor system pkgs) // {
        catalog = (gymFor "x86_64-linux" nixpkgs.legacyPackages.x86_64-linux).catalog;
      };

      packages = forAllSystems (
        system: pkgs:
        let gym = gymFor system pkgs;
        in lib.mapAttrs (id: _: gym.run id seed) gym.challengeFiles
          // { gym = pkgs.callPackage ./gym { }; default = pkgs.callPackage ./gym { }; }
      );

      # Self-tests: unsolved -> check fails, wrong solutions fail, solution passes.
      checks = forAllSystems (
        system: pkgs:
        let gym = gymFor system pkgs;
        in lib.concatMapAttrs (
          id: _:
          lib.listToAttrs (map (s: lib.nameValuePair
            (if s == defaultSeed then id else "${id}-seed-${toString s}")
            (gym.selfTest id s)) testSeeds)
        ) gym.challengeFiles
      );

      devShells = forAllSystems (system: pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.bashInteractive self.packages.${system}.gym ];
        };
      });
    };
}
