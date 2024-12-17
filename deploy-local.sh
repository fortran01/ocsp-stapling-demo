#!/bin/bash
set -e

DOMAIN="ocsp-demo.rara.dev"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "This script requires sudo privileges to modify /etc/hosts"
    echo "Please enter your password to proceed:"
    sudo -v || { echo "Failed to obtain sudo privileges. Exiting."; exit 1; }
fi

# Add domain to /etc/hosts if not already present
if ! sudo grep -q "$DOMAIN" /etc/hosts; then
    echo "Adding $DOMAIN to /etc/hosts..."
    echo "127.0.0.1 $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
else
    echo "$DOMAIN already in /etc/hosts"
fi

# Create SSL directory if it doesn't exist
mkdir -p nginx/ssl/$DOMAIN

# Check if certificates exist
if [ ! -f "nginx/ssl/$DOMAIN/fullchain.pem" ] || \
   [ ! -f "nginx/ssl/$DOMAIN/privkey.pem" ] || \
   [ ! -f "nginx/ssl/$DOMAIN/chain.pem" ]; then
    echo "SSL certificates not found. Please copy your certificates to nginx/ssl/$DOMAIN/"
    echo "Required files:"
    echo "- fullchain.pem"
    echo "- privkey.pem"
    echo "- chain.pem"
    exit 1
fi

# Start the containers
docker compose down
docker compose up --build

echo "Deployment complete!"
echo "You can now access the site at:"
echo "http://$DOMAIN:9080"
echo "https://$DOMAIN:9443"
echo ""
echo "To test OCSP stapling, run:"
echo "openssl s_client -connect $DOMAIN:9443 -status"
