#!/bin/bash

# Flask Redirect Server Cleanup Script for Ubuntu VM
# This script removes the Flask app setup, including directories, services, and configs.
# Also removes tracker.py and its output log.
# Run as the same non-root user who ran the setup (e.g., azureuser).
# Usage: chmod +x cleanup.sh && ./cleanup.sh

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

# Confirmation prompt
print_warning "This script will REMOVE the redirect-app setup (files, services, configs, including tracker.py and user_clicks_tracked.txt)."
read -p "Type 'CONFIRM' to proceed: " CONFIRM
if [[ "$CONFIRM" != "CONFIRM" ]]; then
    print_status "Aborted."
    exit 0
fi

# Check if running as root (avoid)
if [[ $EUID -eq 0 ]]; then
    print_error "Do not run as root. Use a sudo user (e.g., azureuser)."
fi

# Define paths
PROJECT_DIR="/var/www/redirect-app"
LOG_DIR="/var/log/redirect-app"
SERVICE_FILE="/etc/systemd/system/redirect-app.service"
NGINX_SITE="/etc/nginx/sites-available/redirect-app"
NGINX_ENABLED="/etc/nginx/sites-enabled/redirect-app"
TRACKER_OUTPUT="$LOG_DIR/user_clicks_tracked.txt"  # Now in LOG_DIR

# Stop and disable services
print_status "Stopping and disabling services..."
sudo systemctl stop redirect-app 2>/dev/null || true
sudo systemctl disable redirect-app 2>/dev/null || true
sudo systemctl stop nginx 2>/dev/null || true  # Reload if needed, but stop for safety

# Remove systemd service
sudo rm -f "$SERVICE_FILE"
sudo systemctl daemon-reload

# Remove Nginx config
sudo rm -f "$NGINX_SITE"
sudo rm -f "$NGINX_ENABLED"
sudo nginx -t 2>/dev/null || true  # Test config
sudo systemctl reload nginx 2>/dev/null || true

# Remove directories and files
print_status "Removing directories and files..."
sudo rm -rf "$PROJECT_DIR"  # Includes tracker.py, redirect_server.py, venv, .env, user_list.csv if present
sudo rm -rf "$LOG_DIR"      # Includes utm_*.txt and user_clicks_tracked.txt

# Optional: Re-enable default Nginx site (if desired)
print_warning "Default Nginx site not re-enabled. Run 'sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/' if needed."

# UFW: Remove Nginx HTTP rule (optional, comment if you want to keep)
# sudo ufw delete allow 'Nginx HTTP'

print_status "Cleanup complete! All components removed."
print_status "To verify: sudo systemctl status redirect-app (should say not-found)"
print_status "Nginx: sudo nginx -t"