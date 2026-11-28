cd /root/evidence
roots=$(grep 'Accepted password for root' auth.log | awk '{print $11}')
main=$(echo "$roots" | sort | uniq -c | sort -rn | awk 'NR == 1 { print $2 }')
year=$(head -n 1 dpkg.log | cut -c1-4)
last=$(grep "Accepted password for root from $main " auth.log | tail -n 1 | awk '{print $1, $2, $3}')
backdoor=$(grep 'new user' auth.log | grep -v 'name=deploy' | sed 's/.*name=\([^,]*\),.*/\1/')
{
  echo "1: ssh"
  echo "2: $(head -n 1 dmesg | awk '{print $5}')"
  echo "3: root"
  echo "4: $(echo "$roots" | sort -u | wc -l)"
  echo "5: $main"
  echo "6: $(wc -l < apache2/www-access.log)"
  echo "7: $(grep "sudo\[[0-9]*\]: *$backdoor : " auth.log | grep -c 'iptables -A')"
  echo "8: nmap"
  echo "9: $(date -d "$last $year" '+%m/%d/%Y %I:%M:%S %p')"
  echo "10: $(grep -o 'contains [0-9]* root accounts without password' daemon.log | awk '{print $2}')"
  echo "11: $backdoor"
  echo "12: $(grep -E '"(GET http|CONNECT) ' apache2/www-access.log | awk -F'"' '{print $6}' | sort -u)"
} > /root/answers.txt
