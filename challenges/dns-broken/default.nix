# Based on the SadServers scenario "Jakarta": it's always DNS (https://sadservers.com/scenario/jakarta).
{
  title = "It's always DNS";
  difficulty = "medium";
  task = ./task.md;
  answer = ./README.md;
  check = ./check.sh;
  solution = ./solution.sh;
  machine = import ./machine.nix;
}
