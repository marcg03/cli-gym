nginx is installed on this machine and managed by systemd, but nothing answers
on port 80:

    curl -I 127.0.0.1:80
    curl: (7) Failed to connect to 127.0.0.1 port 80: Connection refused

Fix it so that `curl -Is 127.0.0.1:80 | head -1` prints `HTTP/1.1 200 OK` and
nginx serves its default page.

- nginx must run as the systemd service `nginx`, not started by hand.
