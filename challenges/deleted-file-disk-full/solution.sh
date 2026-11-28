pid=$(systemctl show -p MainPID --value ledger)
exec 9< "/proc/$pid/fd/3"          # hold the deleted file open ourselves
systemctl reload ledger            # ledger reopens a fresh ledger.log on SIGHUP
sleep 3                            # it handles the signal after its current sleep
cat <&9 > /root/ledger.log.1       # copy it out; nothing writes to it any more
exec 9<&-                          # last handle closed: the space is freed
