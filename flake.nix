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

      # Seeds that are pure flake outputs (prebuildable, cacheable, self-tested).
      fixedSeeds = [ 1 2 3 4 5 ];

      gymFor = system: pkgs: import ./lib {
        inherit lib pkgs system nixpkgs microvm;
        challengeDir = ./challenges;
      };
    in
    {
      # lib.<system>.runWith { id; seed; kvm; } -> microVM runner (used by `gym start` for free-form seeds)
      # lib.catalog / lib.fixedSeeds          -> metadata for `gym list` / `gym start`
      lib = forAllSystems (system: pkgs: gymFor system pkgs) // {
        # Metadata for `gym list` (evaluated at seed 1).
        catalog = (gymFor "x86_64-linux" nixpkgs.legacyPackages.x86_64-linux).catalog;
        inherit fixedSeeds;
      };

      packages = forAllSystems (
        system: pkgs:
        let
          gym = gymFor system pkgs;
          perSeed = lib.concatMapAttrs (
            id: _:
            lib.listToAttrs (
              map (seed: lib.nameValuePair "${id}-s${toString seed}" (gym.run id seed)) fixedSeeds
            )
            // { ${id} = gym.run id 1; }
          ) gym.challengeFiles;
        in
        perSeed // { gym = pkgs.callPackage ./gym { }; default = pkgs.callPackage ./gym { }; }
      );

      # Every fixed seed of every challenge: unsolved -> check fails, solution -> check passes.
      checks = forAllSystems (
        system: pkgs:
        let gym = gymFor system pkgs;
        in lib.concatMapAttrs (
          id: _:
          lib.listToAttrs (
            map (seed: lib.nameValuePair "${id}-s${toString seed}" (gym.selfTest id seed)) fixedSeeds
          )
        ) gym.challengeFiles
      );

      devShells = forAllSystems (system: pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.bashInteractive self.packages.${system}.gym ];
        };
      });
    };
}
