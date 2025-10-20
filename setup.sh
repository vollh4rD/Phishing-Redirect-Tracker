#!/bin/bash

# Flask Redirect Server Setup Script for Ubuntu VM
# This script sets up the entire Flask app, Gunicorn, Nginx, and services.
# Assumes redirect_server.py and tracker.py are already in the current directory.
# Excludes SSL/Certbot setup.
# Run as a non-root user with sudo privileges (e.g., azureuser).
# Usage: Place redirect_server.py and tracker.py in the same folder, then chmod +x setup.sh && ./setup.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if running as root (avoid)
if [[ $EUID -eq 0 ]]; then
    print_error "Do not run as root. Use a sudo user (e.g., azureuser)."
fi

# Check for required files
if [[ ! -f "redirect_server.py" ]]; then
    print_error "redirect_server.py not found in current directory. Place it here and rerun."
fi

if [[ ! -f "tracker.py" ]]; then
    print_error "tracker.py not found in current directory. Place it here and rerun."
fi

# Update system and install base packages
print_status "Updating system and installing base packages..."
sudo apt update && sudo apt upgrade -y || print_error "Failed to update system."
sudo apt install -y python3 python3-pip python3-venv nginx ufw curl || print_error "Failed to install base packages."

# Enable UFW and allow SSH/HTTP
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx HTTP'
sudo ufw --force enable
print_status "UFW enabled with SSH and HTTP allowed."

# User inputs
print_status "Gathering configuration inputs..."

read -p "Enter your domain (e.g., domain.com): " DOMAIN
if [[ -z "$DOMAIN" ]]; then
    print_error "Domain is required."
fi

read -p "Do you need a subdomain? (y/n): " SUBDOMAIN_NEEDED
if [[ "$SUBDOMAIN_NEEDED" == "y" || "$SUBDOMAIN_NEEDED" == "Y" ]]; then
    read -p "Enter subdomain name (e.g., servicedesk ): " SUBDOMAIN
    if [[ -z "$SUBDOMAIN" ]]; then
        print_error "Subdomain name is required."
    fi
    SERVER_NAME="${SUBDOMAIN}.${DOMAIN}"
else
    SERVER_NAME="$DOMAIN"
fi

read -p "Enter Microsoft Form URL (e.g., https://forms.office.com/r/your-form-id): " MS_FORM_URL
if [[ -z "$MS_FORM_URL" ]]; then
    print_error "MS_FORM_URL is required."
fi

read -p "Enter route path (default: /user-migration-form): " ROUTE_PATH
ROUTE_PATH=${ROUTE_PATH:-"/user-migration-form"}

read -p "Enter CSV file for user data (default: user_list.csv; place it in project dir later): " CSV_FILE
CSV_FILE=${CSV_FILE:-"user_list.csv"}

print_status "Configuration: Domain=$DOMAIN, Server Name=$SERVER_NAME, Form URL=$MS_FORM_URL, Route Path=$ROUTE_PATH, CSV=$CSV_FILE"

# Create directories
PROJECT_DIR="/var/www/redirect-app"
LOG_DIR="/var/log/redirect-app"
sudo mkdir -p "$PROJECT_DIR" "$LOG_DIR"
sudo chown -R $USER:$USER "$PROJECT_DIR" "$LOG_DIR"
sudo chmod 755 "$PROJECT_DIR" "$LOG_DIR"

cd "$PROJECT_DIR" || print_error "Failed to cd to $PROJECT_DIR"

# Copy files
cp "../redirect_server.py" . || print_error "Failed to copy redirect_server.py"
cp "../tracker.py" . || print_error "Failed to copy tracker.py"

# Create .env file
cat > .env << EOF
MS_FORM_URL=$MS_FORM_URL
ROUTE_PATH=$ROUTE_PATH
LOG_DIR=$LOG_DIR
EOF

# Set up Python venv and install deps
print_status "Setting up Python venv and installing dependencies..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install flask gunicorn python-dotenv
deactivate
sudo chown -R $USER:$USER venv

# Set up Gunicorn systemd service
sudo tee /etc/systemd/system/redirect-app.service > /dev/null << EOF
[Unit]
Description=Gunicorn instance for redirect app
After=network.target

[Service]
User=$USER
Group=$USER
WorkingDirectory=$PROJECT_DIR
Environment="PATH=$PROJECT_DIR/venv/bin"
ExecStart=$PROJECT_DIR/venv/bin/gunicorn --workers 3 --bind unix:$PROJECT_DIR/redirect-app.sock redirect_server:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start redirect-app
sudo systemctl enable redirect-app

# Wait and check service
sleep 5
if sudo systemctl is-active --quiet redirect-app; then
    print_status "Gunicorn service started successfully."
else
    print_warning "Gunicorn service may have issues. Check: sudo systemctl status redirect-app"
fi

# Set up Nginx
print_status "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/redirect-app > /dev/null << EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        include proxy_params;
        proxy_pass http://unix:$PROJECT_DIR/redirect-app.sock;
    }

    access_log /var/log/nginx/redirect-app.access.log;
    error_log /var/log/nginx/redirect-app.error.log;
}
EOF

sudo ln -sf /etc/nginx/sites-available/redirect-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl restart nginx || print_error "Nginx config test failed."

print_status "Setup complete! Your site is at http://$SERVER_NAME$ROUTE_PATH"
print_status "Test: curl http://localhost$ROUTE_PATH?utm-id=test"
print_status "Logs: tail -f $LOG_DIR/utm_id_clicks.txt"
print_status "To track users: Place user_list.csv in $PROJECT_DIR, then cd $PROJECT_DIR && source venv/bin/activate && python tracker.py"
print_warning "Next: Set DNS A record for $SERVER_NAME to VM IP, then run SSL setup manually."
print_status "To restart: sudo systemctl restart redirect-app nginx"