# Writes the evidence logs of web01 into the folder given as argument.
# Deterministic: the same files every build, so the answers never change.
import os, random, sys
from datetime import datetime, timedelta

out = sys.argv[1]
rng = random.Random(20240312)
HOST = "web01"
YEAR = 2024

def ts(t):  # syslog time, as Ubuntu writes it: no year
    return t.strftime("%b ") + f"{t.day:2d}" + t.strftime(" %H:%M:%S")

def at(month, day, h, m, s):
    return datetime(YEAR, month, day, h, m, s)

def ip(net):  # documentation ranges only, never a real host
    return f"{net}.{rng.randint(2, 254)}"

auth = []      # (time, text)
pid = [2000]
def npid():
    pid[0] += rng.randint(1, 40)
    return pid[0]

def line(t, prog, msg, p=None):
    auth.append((t, f"{ts(t)} {HOST} {prog}[{p or npid()}]: {msg}"))

def failures(src, start, n, users=("root",), gap=(1, 4)):
    t = start
    for _ in range(n):
        t += timedelta(seconds=rng.randint(*gap))
        u = rng.choice(users)
        p, port = npid(), rng.randint(32768, 60999)
        if u == "root":
            line(t, "sshd", f"pam_unix(sshd:auth): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost={src}  user=root", p)
            line(t, "sshd", f"Failed password for root from {src} port {port} ssh2", p)
        else:
            line(t, "sshd", f"Invalid user {u} from {src} port {port}", p)
            line(t, "sshd", f"Failed password for invalid user {u} from {src} port {port} ssh2", p)
    return t

def session(t, user, src, method, minutes, uid=0):
    p = npid()
    line(t, "sshd", f"Accepted {method} for {user} from {src} port {rng.randint(32768, 60999)} ssh2", p)
    line(t, "sshd", f"pam_unix(sshd:session): session opened for user {user}(uid={uid}) by (uid=0)", p)
    line(t, "systemd-logind", f"New session {rng.randint(10, 999)} of user {user}.")
    end = t + timedelta(minutes=minutes, seconds=rng.randint(0, 59))
    line(end, "sshd", f"Received disconnect from {src} port {rng.randint(32768, 60999)}:11: disconnected by user", p)
    line(end, "sshd", f"pam_unix(sshd:session): session closed for user {user}", p)
    return end

def sudo(t, user, cmd, pwd="/home/dana"):
    line(t, "sudo", f"   {user} : TTY=pts/0 ; PWD={pwd} ; USER=root ; COMMAND={cmd}")
    line(t, "sudo", f"pam_unix(sudo:session): session opened for user root(uid=0) by {user}(uid={1000 if user == 'dana' else 1002})")

def useradd(t, name, uid):
    p = npid()
    line(t, "groupadd", f"group added to /etc/group: name={name}, GID={uid}", p)
    line(t, "groupadd", f"new group: name={name}, GID={uid}", p)
    line(t, "useradd", f"new user: name={name}, UID={uid}, GID={uid}, home=/home/{name}, shell=/bin/bash, from=/dev/pts/0", npid())
    line(t + timedelta(seconds=9), "passwd", f"pam_unix(passwd:chauthtok): password changed for {name}")

# The admin, dana, from the office. Public key logins, every working day.
OFFICE = "192.168.1.20"
day = at(3, 3, 9, 0, 0)
while day < at(3, 25, 0, 0, 0):
    if day.weekday() < 5:
        for _ in range(rng.choice([1, 2])):
            t = day + timedelta(hours=rng.randint(0, 8), minutes=rng.randint(0, 59), seconds=rng.randint(0, 59))
            session(t, "dana", OFFICE, "publickey", rng.randint(5, 50), uid=1000)
    day += timedelta(days=1)

# Hourly cron, for noise.
t = at(3, 3, 8, 17, 1)
while t < at(3, 25, 0, 0, 0):
    p = npid()
    line(t, "CRON", "pam_unix(cron:session): session opened for user root(uid=0) by (uid=0)", p)
    line(t + timedelta(seconds=1), "CRON", "pam_unix(cron:session): session closed for user root", p)
    t += timedelta(hours=1)

# dana's own admin work: a deploy user and two web firewall rules.
sudo(at(3, 5, 10, 12, 44), "dana", "/usr/sbin/useradd -m -s /bin/bash deploy")
useradd(at(3, 5, 10, 12, 44), "deploy", 1001)
for r in ["-A INPUT -p tcp --dport 80 -j ACCEPT", "-A INPUT -p tcp --dport 443 -j ACCEPT"]:
    sudo(at(3, 5, 10, 20, rng.randint(0, 59)), "dana", f"/usr/sbin/iptables {r}")
sudo(at(3, 5, 10, 21, 30), "dana", "/usr/sbin/iptables -L -n")
sudo(at(3, 18, 14, 2, 11), "dana", "/usr/bin/apt-get install -y htop")

# Background brute force from many hosts that never get in.
users = ("root", "admin", "test", "oracle", "ubuntu", "postgres", "user", "guest", "git", "ftp")
nets = ["192.0.2", "198.51.100", "203.0.113"]
noisy = set()
while len(noisy) < 30:
    noisy.add(ip(rng.choice(nets)))
for src in sorted(noisy):
    for _ in range(rng.randint(1, 3)):
        start = at(3, rng.randint(4, 24), rng.randint(0, 23), rng.randint(0, 59), 0)
        failures(src, start, rng.randint(20, 300), users)
# The loudest of them all, with no success at all.
DECOY = "203.0.113.200"
for d in (6, 9, 13, 17, 22):
    failures(DECOY, at(3, d, 1, 0, 0), 900, users, gap=(1, 2))

# The attackers: they guessed root's password.
MAIN = "198.51.100.73"
OTHERS = {"203.0.113.41": 3, "192.0.2.150": 2, "198.51.100.9": 1, "203.0.113.88": 1}
end = failures(MAIN, at(3, 12, 2, 10, 3), 1400, ("root",), gap=(1, 2))
first = end + timedelta(seconds=2)
main_logins = [first] + [at(3, d, h, m, s) for d, h, m, s in
               [(12, 4, 18, 30), (13, 1, 2, 55), (14, 3, 30, 12), (15, 22, 47, 8),
                (17, 0, 13, 41), (19, 5, 5, 5), (20, 21, 9, 33), (21, 23, 42, 7)]]
for i, t in enumerate(main_logins):
    session(t, "root", MAIN, "password", rng.randint(3, 40))
# In the first session: a backdoor account with sudo, named to blend in.
useradd(first + timedelta(minutes=4, seconds=12), "systemd-net", 1002)
line(first + timedelta(minutes=4, seconds=40), "usermod", "add 'systemd-net' to group 'sudo'")
line(first + timedelta(minutes=4, seconds=40), "usermod", "add 'systemd-net' to shadow group 'sudo'")
# Two days later, through the backdoor account: a scanner and an open firewall.
t = at(3, 14, 3, 41, 2)
session(t, "systemd-net", MAIN, "password", 25, uid=1002)
sudo(t + timedelta(minutes=1), "systemd-net", "/usr/bin/apt-get install -y nmap", pwd="/home/systemd-net")
for i, r in enumerate(["-A INPUT -p tcp --dport 4444 -j ACCEPT", "-A INPUT -p tcp --dport 31337 -j ACCEPT",
                       f"-A INPUT -s {MAIN} -j ACCEPT", "-A OUTPUT -p tcp --dport 6667 -j ACCEPT"]):
    sudo(t + timedelta(minutes=6, seconds=10 * i), "systemd-net", f"/usr/sbin/iptables {r}", pwd="/home/systemd-net")
sudo(t + timedelta(minutes=7), "systemd-net", "/usr/sbin/iptables -L -n --line-numbers", pwd="/home/systemd-net")
sudo(t + timedelta(minutes=8), "systemd-net", "/usr/sbin/iptables -D INPUT 1", pwd="/home/systemd-net")
for src, n in OTHERS.items():
    start = at(3, rng.randint(13, 20), rng.randint(0, 23), rng.randint(0, 59), 0)
    e = failures(src, start, rng.randint(200, 600), ("root",))
    for k in range(n):
        session(e + timedelta(seconds=3) + timedelta(days=k, hours=rng.randint(0, 5)), "root", src, "password", rng.randint(2, 15))

os.makedirs(f"{out}/apache2", exist_ok=True)
auth.sort(key=lambda x: x[0])
with open(f"{out}/auth.log", "w") as f:
    f.writelines(l + "\n" for _, l in auth)

# Kernel: the boot banner in dmesg and kern.log.
banner = ("Linux version 5.15.0-97-generic (buildd@lcy02-amd64-102) (gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0, "
          "GNU ld (GNU Binutils for Ubuntu) 2.38) #107-Ubuntu SMP Wed Feb 7 13:26:48 UTC 2024 "
          "(Ubuntu 5.15.0-97.107-generic 5.15.136)")
kmsgs = [banner, "Command line: BOOT_IMAGE=/boot/vmlinuz-5.15.0-97-generic root=/dev/sda1 ro quiet",
         "KERNEL supported cpus:", "  Intel GenuineIntel", "  AMD AuthenticAMD",
         "BIOS-provided physical RAM map:", "DMI: QEMU Standard PC (i440FX + PIIX, 1996)",
         "Hypervisor detected: KVM", "Memory: 2013492K/2096632K available", "NET: Registered PF_INET protocol family",
         "EXT4-fs (sda1): mounted filesystem with ordered data mode. Quota mode: none.",
         "e1000 0000:00:03.0 eth0: (PCI:33MHz:32-bit) 52:54:00:12:34:56",
         "e1000: eth0 NIC Link is Up 1000 Mbps Full Duplex, Flow Control: RX"]
with open(f"{out}/dmesg", "w") as d, open(f"{out}/kern.log", "w") as k:
    for i, m in enumerate(kmsgs):
        stamp = f"[{i * 0.137:12.6f}]"
        d.write(f"{stamp} {m}\n")
        k.write(f"{ts(at(3, 3, 8, 0, 1))} {HOST} kernel: {stamp} {m}\n")

# Packages: dpkg.log has full dates, the only place with the year.
dpkg = []
def install(t, pkgs):
    for p, v in pkgs:
        dpkg.append(f"{t:%Y-%m-%d %H:%M:%S} install {p}:amd64 <none> {v}")
        dpkg.append(f"{t:%Y-%m-%d %H:%M:%S} status half-installed {p}:amd64 {v}")
        t += timedelta(seconds=1)
        dpkg.append(f"{t:%Y-%m-%d %H:%M:%S} status installed {p}:amd64 {v}")
        t += timedelta(seconds=rng.randint(0, 2))
install(at(3, 3, 8, 30, 12), [("libapr1", "1.7.0-8ubuntu0.22.04.1"), ("libaprutil1", "1.6.1-5ubuntu4.22.04.2"),
        ("apache2-bin", "2.4.52-1ubuntu4.7"), ("apache2-data", "2.4.52-1ubuntu4.7"), ("apache2", "2.4.52-1ubuntu4.7"),
        ("mysql-common", "5.8+1.0.8"), ("mysql-client-8.0", "8.0.36-0ubuntu0.22.04.1"),
        ("mysql-server-8.0", "8.0.36-0ubuntu0.22.04.1"), ("mysql-server", "8.0.36-0ubuntu0.22.04.1")])
install(at(3, 9, 6, 2, 40), [("libssl3", "3.0.2-0ubuntu1.14"), ("openssl", "3.0.2-0ubuntu1.14")])
install(at(3, 14, 3, 42, 15), [("libblas3", "3.10.0-2ubuntu1"), ("liblinear4", "2.3.0+dfsg-5"),
        ("liblua5.3-0", "5.3.6-1build1"), ("lua-lpeg", "1.0.2-1"), ("libpcap0.8", "1.10.1-4build1"),
        ("nmap-common", "7.91+dfsg1+really7.80+dfsg1-2ubuntu0.1"), ("nmap", "7.91+dfsg1+really7.80+dfsg1-2ubuntu0.1")])
install(at(3, 18, 14, 2, 20), [("libnl-genl-3-200", "3.5.0-0.1"), ("htop", "3.0.5-7build2")])
with open(f"{out}/dpkg.log", "w") as f:
    f.writelines(l + "\n" for l in dpkg)

# daemon.log: services starting, and MySQL's checks after its install.
daemon = []
def dmn(t, prog, msg):
    daemon.append((t, f"{ts(t)} {HOST} {prog}: {msg}"))
t0 = at(3, 3, 8, 31, 2)
dmn(t0, "systemd[1]", "Starting MySQL Community Server...")
for i, m in enumerate([
        "[System] [MY-010116] [Server] /usr/sbin/mysqld (mysqld 8.0.36-0ubuntu0.22.04.1) starting as process 4113",
        "[Warning] [MY-010068] [Server] CA certificate ca.pem is self signed.",
        "[Warning] [MY-011810] [Server] Insecure configuration for --pid-file: Location '/var/run/mysqld' in the path is accessible to all OS users. Consider choosing a different directory.",
        "[Warning] [MY-010161] [Server] You need to use --log-bin to make --binlog-format work.",
        "[System] [MY-010931] [Server] /usr/sbin/mysqld: ready for connections. Version: '8.0.36-0ubuntu0.22.04.1'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  (Ubuntu)."]):
    dmn(t0 + timedelta(seconds=2 + i), "mysqld[4113]", m)
dmn(t0 + timedelta(seconds=9), "systemd[1]", "Started MySQL Community Server.")
for i, m in enumerate(["Checking for insecure root accounts.",
                       "WARNING: mysql.user contains 3 root accounts without password!",
                       "Checking for tables which need an upgrade, are corrupt or were not closed cleanly."]):
    dmn(t0 + timedelta(seconds=11 + i), "/etc/mysql/debian-start[4170]", m)
for d in range(3, 25):
    t = at(3, d, 0, 0, 0) + timedelta(minutes=rng.randint(0, 50))
    dmn(t, "systemd[1]", "Starting Rotate log files...")
    dmn(t + timedelta(seconds=1), "systemd[1]", "logrotate.service: Deactivated successfully.")
    dmn(t + timedelta(seconds=1), "systemd[1]", "Finished Rotate log files.")
    t = at(3, d, 6, 0, 0) + timedelta(minutes=rng.randint(0, 50))
    dmn(t, "systemd[1]", "Starting Daily apt download activities...")
    dmn(t + timedelta(seconds=4), "systemd[1]", "Finished Daily apt download activities.")
dmn(at(3, 3, 8, 30, 40), "systemd[1]", "Starting The Apache HTTP Server...")
dmn(at(3, 3, 8, 30, 41), "apachectl[3990]", "AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 127.0.1.1. Set the 'ServerName' directive globally to suppress this message")
dmn(at(3, 3, 8, 30, 41), "systemd[1]", "Started The Apache HTTP Server.")
daemon.sort(key=lambda x: x[0])
with open(f"{out}/daemon.log", "w") as f:
    f.writelines(l + "\n" for _, l in daemon)

# Apache: visitors, crawlers, a couple of vulnerability scanners, and a proxy scanner.
pages = ["/", "/", "/", "/about.html", "/contact.html", "/products.html", "/css/site.css", "/js/site.js",
         "/img/logo.png", "/favicon.ico", "/blog/", "/blog/2024/03/spring-sale.html"]
browsers = ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Safari/605.1.15",
            "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:123.0) Gecko/20100101 Firefox/123.0",
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.3 Mobile/15E148 Safari/604.1"]
bots = ["Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
        "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"]
web = []
def req(t, src, method, path, status, size, ua, ref="-"):
    web.append((t, f'{src} - - [{t:%d/%b/%Y:%H:%M:%S} +0000] "{method} {path} HTTP/1.1" {status} {size} "{ref}" "{ua}"'))
visitors = [ip(rng.choice(nets)) for _ in range(90)]
for _ in range(1100):
    t = at(3, rng.randint(3, 24), rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59))
    p = rng.choice(pages)
    req(t, rng.choice(visitors), "GET", p, 200, rng.randint(300, 40000), rng.choice(browsers))
for _ in range(160):
    t = at(3, rng.randint(3, 24), rng.randint(0, 23), rng.randint(0, 59), rng.randint(0, 59))
    req(t, ip("198.51.100"), "GET", rng.choice(pages + ["/robots.txt"]), 200, rng.randint(300, 40000), rng.choice(bots))
for path in ["/.env", "/wp-login.php", "/phpmyadmin/", "/.git/config", "/admin/", "/cgi-bin/test.cgi", "/server-status"]:
    for ua in ["Mozilla/5.00 (Nikto/2.1.6) (Evasions:None) (Test:000001)", "zgrab/0.x"]:
        req(at(3, 11, 15, rng.randint(0, 59), rng.randint(0, 59)), "192.0.2.66", "GET", path, 404, 274, ua)
# The proxy scanner asks for other sites by full URL, to see if this server relays them.
PROXY_UA = "proxyprobe/2.4"
proxy_reqs = 0
for d in (8, 15, 22):
    src = ip("203.0.113")
    for target in ["http://www.example.com/", "http://check.example.net/proxy.txt", "http://198.51.100.250:6667/",
                   "http://www.example.org/index.html", "http://mail.example.com:25/"]:
        req(at(3, d, 4, rng.randint(0, 59), rng.randint(0, 59)), src, "GET", target, 404, 274, PROXY_UA)
        proxy_reqs += 1
    req(at(3, d, 4, 59, 59), src, "CONNECT", "www.example.com:443", 400, 301, PROXY_UA)
    proxy_reqs += 1
web.sort(key=lambda x: x[0])
with open(f"{out}/apache2/www-access.log", "w") as f:
    f.writelines(l + "\n" for _, l in web)

# The answers, recomputed from the data, so a change to this file can't go unnoticed.
last = max(main_logins)
answers = {
    1: "ssh", 2: "5.15.0-97-generic", 3: "root", 4: str(1 + len(OTHERS)), 5: MAIN,
    6: str(len(web)), 7: "4", 8: "nmap", 9: last.strftime("%m/%d/%Y %I:%M:%S %p"),
    10: "3", 11: "systemd-net", 12: PROXY_UA,
}
if len(sys.argv) > 2:
    with open(sys.argv[2], "w") as f:
        f.writelines(f"{k}: {v}\n" for k, v in answers.items())
