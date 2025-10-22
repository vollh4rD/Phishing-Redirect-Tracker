## Stop Everything.
sudo systemctl stop redirect-app  # Stops Gunicorn/Flask
sudo systemctl stop nginx         # Stops web server (no external access)
sudo ufw deny 'Nginx HTTP'    # Blocks ports 80/443
sudo ufw reload

## Resume Later to start everything back up:

sudo systemctl start redirect-app
sudo systemctl start nginx
sudo ufw allow 'Nginx HTTP'  # If you denied earlier
sudo ufw reload

> For full removal, use the cleanup script. If issues, check sudo journalctl -u redirect-app -e