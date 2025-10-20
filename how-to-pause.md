sudo systemctl stop redirect-app  # Stops Gunicorn/Flask
sudo systemctl stop nginx         # Stops web server (no external access)
textsudo ufw deny 'Nginx HTTP'    # Blocks ports 80/443
sudo ufw reload

Resume Later

To start everything back up:
sudo systemctl start redirect-app
sudo systemctl start nginx
sudo ufw allow 'Nginx HTTP'  # If you denied earlier
sudo ufw reload

For full removal, use the cleanup script. If issues, check sudo journalctl -u redirect-app -e