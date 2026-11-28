# nginx set up the way a Debian package would: config in /etc/nginx and a unit file
# systemd loads from disk. All of it is plain files, so it can be fixed at runtime.
# /etc/systemd/system is read-only on NixOS, so the unit goes in /run/systemd/system.
{ pkgs, ... }:
let
  # Like Debian's /usr/sbin/nginx: reads /etc/nginx/nginx.conf by default.
  nginx = pkgs.writeShellScript "nginx" ''
    exec -a nginx ${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf "$@"
  '';

  nginxConf = pkgs.writeText "nginx.conf" ''
    user www-data;
    worker_processes auto;
    pid /run/nginx.pid;
    error_log /var/log/nginx/error.log;

    events {
        worker_connections 768;
    }

    http {
        sendfile on;
        tcp_nopush on;
        types_hash_max_size 2048;
        include /etc/nginx/mime.types;
        default_type application/octet-stream;
        access_log /var/log/nginx/access.log;
        gzip on;
        include /etc/nginx/conf.d/*.conf;
        include /etc/nginx/sites-enabled/*;
    }
  '';

  # Fault 1: a stray semicolon on the first line.
  site = pkgs.writeText "default" ''
    ;
    server {
        listen 80 default_server;
        root /var/www/html;
        index index.html index.htm;
        server_name _;

        location / {
            try_files $uri $uri/ =404;
        }
    }
  '';

  page = pkgs.writeText "index.html" ''
    <!DOCTYPE html>
    <html>
    <head><title>Welcome to nginx!</title></head>
    <body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and working.</p>
    </body>
    </html>
  '';

  # Fault 2: LimitNOFILE=10 leaves nginx too few file descriptors to serve a page.
  unit = pkgs.writeText "nginx.service" ''
    [Unit]
    Description=A high performance web server and a reverse proxy server
    After=network.target

    [Service]
    Type=forking
    PIDFile=/run/nginx.pid
    ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
    ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
    ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
    ExecStop=-/run/current-system/sw/bin/kill -s QUIT $MAINPID
    TimeoutStopSec=5
    KillMode=mixed
    LimitNOFILE=10

    [Install]
    WantedBy=multi-user.target
  '';
in
{
  users.groups.www-data = { };
  users.users.www-data = { isSystemUser = true; group = "www-data"; };

  # Install the files, then start nginx as boot would. It fails.
  systemd.services.nginx-install = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    path = [ pkgs.coreutils pkgs.systemd ];
    script = ''
      mkdir -p /usr/sbin /etc/nginx/conf.d /etc/nginx/sites-available /etc/nginx/sites-enabled \
        /var/www/html /var/log/nginx
      ln -sf ${nginx} /usr/sbin/nginx
      install -m 0644 ${nginxConf} /etc/nginx/nginx.conf
      install -m 0644 ${pkgs.nginx}/conf/mime.types /etc/nginx/mime.types
      install -m 0644 ${site} /etc/nginx/sites-available/default
      ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
      install -m 0644 ${page} /var/www/html/index.html
      install -D -m 0644 ${unit} /run/systemd/system/nginx.service
      systemctl daemon-reload
      systemctl start --no-block nginx.service
    '';
  };

  systemd.services.gym-setup = {
    requires = [ "nginx-install.service" ];
    after = [ "nginx-install.service" ];
  };
}
