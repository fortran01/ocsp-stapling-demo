#!/bin/sh

# Create AWS credentials file for Route53 authentication
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}
EOF

# Request certificate if it doesn't exist
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
    # Activate virtual environment for certbot
    . /opt/certbot-dns/bin/activate
    
    certbot certonly \
        --dns-route53 \
        --non-interactive \
        --agree-tos \
        --email admin@rara.dev \
        -d ${DOMAIN} \
        --preferred-challenges dns-01
    
    # Deactivate virtual environment
    deactivate
fi

# Ensure HAProxy ssl directory exists
mkdir -p /etc/haproxy/ssl/${DOMAIN}

# Create symlinks for HAProxy certificates
ln -sf /etc/letsencrypt/live/${DOMAIN}/fullchain.pem /etc/haproxy/ssl/${DOMAIN}/fullchain.pem
ln -sf /etc/letsencrypt/live/${DOMAIN}/privkey.pem /etc/haproxy/ssl/${DOMAIN}/privkey.pem
ln -sf /etc/letsencrypt/live/${DOMAIN}/chain.pem /etc/haproxy/ssl/${DOMAIN}/chain.pem

# Combine certificate and private key for HAProxy
cat /etc/haproxy/ssl/${DOMAIN}/fullchain.pem \
    /etc/haproxy/ssl/${DOMAIN}/privkey.pem \
    > /etc/haproxy/ssl/${DOMAIN}/combined.pem

# Function to update OCSP response
update_ocsp_response() {
    local domain=$1
    local cert_path="/etc/haproxy/ssl/${domain}"
    
    # Get OCSP responder URL
    OCSP_URL=$(openssl x509 -in "${cert_path}/fullchain.pem" -text -noout | grep "OCSP - URI:" | cut -d: -f2- | tr -d ' ')
    OCSP_HOST=$(echo "${OCSP_URL}" | sed 's|http://||')
    
    echo "Updating OCSP response for ${domain}"
    
    # Generate and verify OCSP response
    openssl ocsp -issuer "${cert_path}/chain.pem" \
                 -cert "${cert_path}/fullchain.pem" \
                 -url "${OCSP_URL}" \
                 -header "Host=${OCSP_HOST}" \
                 -respout "${cert_path}/ocsp.resp" \
                 -verify_other "${cert_path}/chain.pem" \
                 -no_nonce \
                 -timeout 10
    
    if [ -f "${cert_path}/ocsp.resp" ]; then
        echo "OCSP response updated successfully"
    else
        echo "Failed to update OCSP response"
    fi
}

# Initial OCSP response update
update_ocsp_response "${DOMAIN}"

# Start HAProxy in background
haproxy -f /usr/local/etc/haproxy/haproxy.cfg &
HAPROXY_PID=$!

# Set up periodic OCSP update (every 1 hour)
while true; do
    sleep 3600
    update_ocsp_response "${DOMAIN}"
done &

# Wait for HAProxy process
wait ${HAPROXY_PID}
