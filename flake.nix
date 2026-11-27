{
  description = "cli-gym: a LeetCode for the Linux command line, built on Nix and microVMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    microvm = {
      url = "git+https://github.com/microvm-nix/microvm.nix?shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
      # spectrum is only for microvm.nix's graphics support; never fetch it.
      inputs.spectrum.follows = "";
    };
  };

  outputs = { nixpkgs, microvm, ... }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system:
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
