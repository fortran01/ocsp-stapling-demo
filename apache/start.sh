#!/bin/bash

# Create AWS credentials file for Route53 authentication
mkdir -p ~/.aws
cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
aws_session_token = ${AWS_SESSION_TOKEN}
EOF

# Request certificate if it doesn't exist
if [ ! -f "/etc/letsencrypt/live/apache-ocsp.rara.dev/fullchain.pem" ]; then
    # Activate virtual environment for certbot
    . /opt/certbot-dns/bin/activate
    
    certbot certonly \
        --dns-route53 \
        --non-interactive \
        --agree-tos \
        --email admin@rara.dev \
        -d apache-ocsp.rara.dev \
        --preferred-challenges dns-01
    
    # Deactivate virtual environment
    deactivate
fi

# Debug: Check certificate details and OCSP URL
echo "Checking certificate details..."
OCSP_URL=$(openssl x509 -in /etc/letsencrypt/live/apache-ocsp.rara.dev/fullchain.pem -text -noout | grep "OCSP - URI:" | cut -d: -f2- | tr -d ' ')
echo "OCSP URL: ${OCSP_URL}"

# Ensure apache ssl directory exists and create/update symlinks if needed
if [ ! -L "/etc/apache2/ssl/cert.pem" ] || \
   [ ! -L "/etc/apache2/ssl/private.key" ] || \
   [ ! -L "/etc/apache2/ssl/chain.pem" ]; then
    mkdir -p /etc/apache2/ssl
    ln -sf /etc/letsencrypt/live/apache-ocsp.rara.dev/fullchain.pem /etc/apache2/ssl/cert.pem
    ln -sf /etc/letsencrypt/live/apache-ocsp.rara.dev/privkey.pem /etc/apache2/ssl/private.key
    ln -sf /etc/letsencrypt/live/apache-ocsp.rara.dev/chain.pem /etc/apache2/ssl/chain.pem
fi

# Debug: Test OCSP responder directly
echo "Testing OCSP responder..."
OCSP_HOST=$(echo "${OCSP_URL}" | sed 's|http://||')
echo "OCSP Host: ${OCSP_HOST}"

# Create OCSP request
echo "Creating OCSP request..."
openssl x509 -noout -ocsp_uri -in /etc/apache2/ssl/cert.pem

echo "Sending OCSP request..."
openssl ocsp \
    -issuer /etc/apache2/ssl/chain.pem \
    -cert /etc/apache2/ssl/cert.pem \
    -url "${OCSP_URL}" \
    -header "Host=${OCSP_HOST}" \
    -resp_text \
    -noverify \
    -timeout 30

# Debug: Check DNS resolution
echo "Testing DNS resolution..."
for dns in 1.1.1.1 1.0.0.1; do
    echo "Testing resolver ${dns}..."
    dig @${dns} ${OCSP_HOST} +short
    echo "Testing resolver ${dns} with TCP..."
    dig @${dns} ${OCSP_HOST} +tcp +short
done

# Debug: Test OCSP responder connectivity
echo "Testing OCSP responder connectivity..."
curl -v -H "Host: ${OCSP_HOST}" ${OCSP_URL}

# Testing OCSP responder with full certificate chain
echo "Testing OCSP with full chain verification..."
openssl ocsp -issuer /etc/apache2/ssl/chain.pem \
    -cert /etc/apache2/ssl/cert.pem \
    -text \
    -url $OCSP_URL \
    -header Host="$OCSP_HOST" \
    -verify_other /etc/apache2/ssl/chain.pem \
    -CAfile /etc/apache2/ssl/chain.pem

# Additional OCSP verification with nonce
echo "Testing OCSP with nonce..."
openssl ocsp -issuer /etc/apache2/ssl/chain.pem \
    -cert /etc/apache2/ssl/cert.pem \
    -text \
    -url $OCSP_URL \
    -header Host="$OCSP_HOST" \
    -verify_other /etc/apache2/ssl/chain.pem \
    -CAfile /etc/apache2/ssl/chain.pem \
    -nonce

# Pre-fetch and cache OCSP response
echo "Pre-fetching OCSP response..."
mkdir -p /tmp/apache-ocsp-cache
openssl ocsp -issuer /etc/apache2/ssl/chain.pem \
    -cert /etc/apache2/ssl/cert.pem \
    -url $OCSP_URL \
    -header Host="$OCSP_HOST" \
    -respout /tmp/apache-ocsp-cache/response.der \
    -noverify

# Start Apache in foreground
exec httpd -DFOREGROUND
