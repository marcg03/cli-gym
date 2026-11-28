`web01`, a small company web server running Ubuntu, was broken into. Its admin,
dana, works from the office at 192.168.1.20 and logs in with an SSH key. She
pulled the server's logs before rebuilding it. They are in `/root/evidence`.

Investigate, then write your answers to `/root/answers.txt`, one per line, as
`N: answer` (for example `4: 7`):

1. Which service did the attackers use to get in?
2. Which kernel version was the server running?
3. Which account did the attackers break into?
4. How many attackers were there? Count each outside IP address that
   successfully logged in to that account as one attacker.
5. Which attacker IP logged in to that account the most times?
6. How many requests were sent to the web server in total?
7. How many firewall rules did the attackers add?
8. Which scanning tool did the attackers install?
9. When did the attacker from question 5 last log in to that account?
   Format: `MM/DD/YYYY HH:MM:SS AM` (or `PM`).
10. MySQL logged a warning that is a real security hole. How many accounts
    does it name?
11. Which account did the attackers create to keep access?
12. One client was testing the server as an open proxy. What was its user agent?

`gym check` tells you how many answers are right, and which ones.
