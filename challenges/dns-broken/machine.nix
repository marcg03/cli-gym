# A DNS server for shop.internal on this machine, which works, and a resolver
# setup on the same machine that never asks it. Everything is on loopback
# addresses (127.0.0.0/8), so no network is needed.
{ lib, pkgs, ... }:
{
  environment.systemPackages = [ pkgs.dnsutils ];  # dig, host, nslookup

  # The shop.internal zone, served at 127.0.0.5.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      listen-address = "127.0.0.5";
      bind-interfaces = true;
      no-resolv = true;
      no-hosts = true;
      local = "/shop.internal/";
      host-record = [
        "api.shop.internal,127.0.0.10"
        "db.shop.internal,127.0.0.11"
        "status.shop.internal,127.0.0.12"
      ];
    };
  };

  # A plain resolver, as on a small Debian or Ubuntu server: no name service
  # cache, no systemd-resolved, and files the player can edit.
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];
  services.resolved.enable = false;
  networking.resolvconf.enable = false;
  environment.etc."resolv.conf" = {
    text = "nameserver 127.0.0.5\n";
    mode = "0644";
  };
  environment.etc.hosts.mode = "0644";

  # The fault: the hosts line lists only "files", so DNS is never asked.
  environment.etc."nsswitch.conf" = {
    text = lib.mkForce ''
      passwd:    files
      group:     files
      shadow:    files

      hosts:     files
      networks:  files

      protocols: files
      services:  files
      ethers:    files
      rpc:       files
    '';
    mode = "0644";
  };

  systemd.services.gym-setup = {
    requires = [ "dnsmasq.service" ];
    after = [ "dnsmasq.service" ];
  };
}
