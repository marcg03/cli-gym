sed -i '1{/^;$/d}' /etc/nginx/sites-available/default   # 1. the stray semicolon
sed -i '/^LimitNOFILE=10$/d' /run/systemd/system/nginx.service  # 2. the file limit
systemctl daemon-reload
systemctl reset-failed nginx
systemctl restart nginx
sleep 1
