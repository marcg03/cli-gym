# A small data volume for a web shop, and a session folder nobody ever cleaned.
{ pkgs, ... }:
let
  # Every login creates an empty session file. When that fails, nobody can log in.
  shop = pkgs.writeShellScriptBin "shop" ''
    dir=/srv/shop/sessions
    while true; do
      id=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')
      if : > "$dir/sess_$id" 2>/dev/null; then
        echo "login ok, session $id"
      else
        echo "login failed: cannot create $dir/sess_$id: No space left on device"
      fi
      sleep 5
    done
  '';
in
{
  # 64 MiB but only 60000 inodes: every file, folder and symlink takes one.
  systemd.mounts = [{
    what = "tmpfs";
    where = "/srv";
    type = "tmpfs";
    options = "size=64M,nr_inodes=60000,mode=0755";
    wantedBy = [ "local-fs.target" ];
  }];

  # Months of sessions, replayed on every boot. The shop never expired them,
  # and bots opened a new one on every request.
  systemd.services.shop-history = {
    wantedBy = [ "multi-user.target" ];
    requires = [ "srv.mount" ];
    after = [ "srv.mount" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    path = [ pkgs.coreutils pkgs.findutils ];
    script = ''
      mkdir -p /srv/shop/sessions /srv/shop/uploads /srv/shop/backup
      cd /srv/shop
      now=$(date +%s)

      # Things to keep: product images, last night's database dump, live sessions.
      for i in $(seq -w 1 300); do
        echo "image $i" > uploads/product-$i.jpg
      done
      head -c 30M /dev/zero > backup/shop-db-2026-11-27.sql
      # Live sessions, 0 to 20 hours idle. check.sh looks for these by name.
      for i in $(seq -w 1 20); do
        touch -d "@$((now - 10#$i * 3600 + 1800))" sessions/sess_live$i
      done

      # Dead sessions, 3 to 60 days old, until the inodes run out.
      head -c $((70000 * 16)) /dev/urandom | od -An -tx1 -v -w16 | tr -d ' ' \
        | sed 's/^/sess_/' | split -l 1000 - /run/sess-chunk.
      day=3
      cd sessions
      for chunk in /run/sess-chunk.*; do
        xargs touch -d "@$((now - day * 86400))" < "$chunk" 2>/dev/null || break
        day=$((day < 60 ? day + 1 : 3))
      done
      rm -f /run/sess-chunk.*
      df --output=itotal /srv | tail -n 1 | tr -dc 0-9 > /run/gym-inodes
    '';
  };

  systemd.services.shop = {
    description = "Web shop";
    wantedBy = [ "multi-user.target" ];
    requires = [ "shop-history.service" ];
    after = [ "shop-history.service" ];
    serviceConfig = {
      ExecStart = "${shop}/bin/shop";
      Restart = "always";
    };
  };

  # gym check should only run once the history is in place.
  systemd.services.gym-setup = {
    requires = [ "shop-history.service" ];
    after = [ "shop-history.service" ];
  };
}
