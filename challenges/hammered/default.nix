# Based on the CyberDefenders lab "Hammered" (https://cyberdefenders.org/blueteam-ctf-challenges/hammered/).
{
  title = "Hammered";
  difficulty = "hard";
  task = ./task.md;
  answer = ./README.md;
  check = ./check.sh;
  solution = ./solution.sh;
  machine = import ./machine.nix;
}
