# An internal DNS server and the shop API on this machine, and a resolver
# setup left over from before last week's DNS migration. Everything lives on
# loopback addresses (127.0.0.0/8), so no network is needed.
{ pkgs, ... }:
let
  site = pkgs.writeTextDir "index.html" "shop api: ok\n";
in
{
  environment.systemPackages = [ pkgs.dnsutils ];  # dig, host, nslookup

  # The shop.internal zone, served by the new DNS server at 127.0.0.5.
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

  systemd.services.shop-api = {
    description = "Shop API";
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.darkhttpd}/bin/darkhttpd ${site} --addr 127.0.0.10 --port 80";
  };

  # The faults. Both files are plain, writable copies, not links into the Nix store.
  # The old DNS server, 127.0.0.4, was switched off in the migration.
  networking.resolvconf.enable = false;
  services.resolved.enable = false;  # the microVM turns it on; it would own resolv.conf
  environment.etc."resolv.conf" = {
    text = ''
      # DNS for shop.internal
      nameserver 127.0.0.4
    '';
    mode = "0644";
  };
  # A workaround someone added during an outage, pointing at the API's old address.
  networking.extraHosts = ''
    127.0.0.20 api.shop.internal
  '';
  environment.etc.hosts.mode = "0644";

  systemd.services.gym-setup = {
    requires = [ "dnsmasq.service" "shop-api.service" ];
    after = [ "dnsmasq.service" "shop-api.service" ];
  };
}
