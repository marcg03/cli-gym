sed -i '/shop\.internal/d' /etc/hosts                       # drop the stale workaround
sed -i 's/^nameserver .*/nameserver 127.0.0.5/' /etc/resolv.conf  # point at the new server
