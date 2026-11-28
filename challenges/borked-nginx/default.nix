# Based on the SadServers scenario "Cape Town": Borked Nginx (https://sadservers.com/scenario/capetown).
{
  title = "Borked nginx";
  difficulty = "medium";
  task = ./task.md;
  answer = ./README.md;
  check = ./check.sh;
  solution = ./solution.sh;
  machine = import ./machine.nix;
}
