{
  description = "cli-gym: a LeetCode for the Linux command line, built on Nix and microVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Linux only: challenges are NixOS VMs.
    systems.url = "github:nix-systems/default-linux";
    microvm = {
      url = "git+https://github.com/microvm-nix/microvm.nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      # spectrum is only for microvm.nix's graphics support; never fetch it.
      inputs.spectrum.follows = "";
    };
  };

  outputs = { nixpkgs, microvm, systems, ... }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs (import systems) (system:
        f (import ./lib {
          inherit (nixpkgs) lib;
          inherit nixpkgs microvm;
          pkgs = nixpkgs.legacyPackages.${system};
          challengeDir = ./challenges;
        }));
    in
    {
      packages = forAllSystems (gym: gym.vms);
      checks = forAllSystems (gym: gym.tests);
      devShells = forAllSystems (gym: { default = gym.shell; });
    };
}
