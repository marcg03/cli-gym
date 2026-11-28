# The logs of a breached web server, copied to /root/evidence on every boot.
# generate.py writes them, the same every build, from original made-up data.
{ pkgs, ... }:
let
  evidence = pkgs.runCommand "hammered-evidence" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./generate.py} $out
  '';
in
{
  systemd.services.gym-setup.script = ''
    cp -r --no-preserve=mode ${evidence} /root/evidence
  '';
}
