# Host-side `gym` CLI: list challenges and boot one.
{ writeShellApplication, jq, coreutils, util-linux }:
writeShellApplication {
  name = "gym";
  runtimeInputs = [ jq coreutils util-linux ];
  text = builtins.readFile ./gym.sh;
}
