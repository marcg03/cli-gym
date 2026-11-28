# A small log volume, a payment service writing to it, and the incident that filled it.
{ pkgs, ... }:
let
  # The service appends a line every two seconds. Like many daemons it reopens
  # its log on SIGHUP, which is what logrotate should have sent it.
  ledger = pkgs.writeShellScript "ledger" ''
    log=/var/log/ledger/ledger.log
    exec 3>>"$log"
    trap 'exec 3>>"$log"' HUP
    n=0
    while true; do
      n=$((n + 1))
      echo "$(date -Is) txn $n settled" >&3
      sleep 2
    done
  '';
in
{
  environment.systemPackages = [ pkgs.lsof ];

  systemd.mounts = [{
    what = "tmpfs";
    where = "/var/log/ledger";
    type = "tmpfs";
    options = "size=40M,mode=0755";
    wantedBy = [ "local-fs.target" ];
  }];

  systemd.services.ledger = {
    description = "Ledger payment settlement";
    wantedBy = [ "multi-user.target" ];
    requires = [ "var-log-ledger.mount" ];
    after = [ "var-log-ledger.mount" ];
    serviceConfig = {
      ExecStart = ledger;
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "always";
    };
  };

  # Yesterday's story, replayed on every boot: a debug flag filled the log,
  # logrotate renamed it without telling the service, and someone deleted the
  # rotated file to make room. The service still holds it open.
  systemd.services.ledger-incident = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "ledger.service" ];
    after = [ "ledger.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    path = [ pkgs.coreutils pkgs.systemd ];
    script = ''
      cd /var/log/ledger
      for day in 25 26 27; do
        for i in 1 2 3 4 5; do
          echo "2026-11-$day audit: batch $i reconciled"
        done > audit-2026-11-$day.log
      done
      yes "DEBUG ledger: dumping settlement cache entry, state=ok" | head -c 36M >> ledger.log
      mv ledger.log ledger.log.1
      : > ledger.log
      rm ledger.log.1
      systemctl show -p MainPID --value ledger > /run/ledger.pid
    '';
  };

  # gym check should only run once the incident has happened.
  systemd.services.gym-setup = {
    requires = [ "ledger-incident.service" ];
    after = [ "ledger-incident.service" ];
  };
}
