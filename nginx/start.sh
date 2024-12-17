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
if [ ! -f "/etc/letsencrypt/live/ocsp-demo.rara.dev/fullchain.pem" ]; then
    # Activate virtual environment for certbot
    . /opt/certbot-dns/bin/activate
    
    certbot certonly \
        --dns-route53 \
        --non-interactive \
        --agree-tos \
        --email admin@rara.dev \
        -d ocsp-demo.rara.dev \
        --preferred-challenges dns-01
    
    # Deactivate virtual environment
    deactivate
fi

# Debug: Check certificate details and OCSP URL
echo "Checking certificate details..."
OCSP_URL=$(openssl x509 -in /etc/letsencrypt/live/ocsp-demo.rara.dev/fullchain.pem -text -noout | grep "OCSP - URI:" | cut -d: -f2- | tr -d ' ')
echo "OCSP URL: ${OCSP_URL}"

# Ensure nginx ssl directory exists and create/update symlinks if needed
if [ ! -L "/etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem" ] || \
   [ ! -L "/etc/nginx/ssl/ocsp-demo.rara.dev/privkey.pem" ] || \
   [ ! -L "/etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem" ]; then
    mkdir -p /etc/nginx/ssl/ocsp-demo.rara.dev
    ln -sf /etc/letsencrypt/live/ocsp-demo.rara.dev/fullchain.pem /etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem
    ln -sf /etc/letsencrypt/live/ocsp-demo.rara.dev/privkey.pem /etc/nginx/ssl/ocsp-demo.rara.dev/privkey.pem
    ln -sf /etc/letsencrypt/live/ocsp-demo.rara.dev/chain.pem /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem
fi

# Debug: Test OCSP responder directly
echo "Testing OCSP responder..."
OCSP_HOST=$(echo "${OCSP_URL}" | sed 's|http://||')
echo "OCSP Host: ${OCSP_HOST}"

# Create OCSP request
echo "Creating OCSP request..."
openssl x509 -noout -ocsp_uri -in /etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem

echo "Sending OCSP request..."
openssl ocsp \
    -issuer /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -cert /etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem \
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

# Testing OCSP responder...
echo "OCSP Host: $OCSP_HOST"
echo "Creating OCSP request..."
echo "$OCSP_URL"
echo "Sending OCSP request..."

# Test OCSP responder with full certificate chain
openssl ocsp -issuer /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -cert /etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem \
    -text \
    -url $OCSP_URL \
    -header Host="$OCSP_HOST" \
    -verify_other /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -CAfile /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem

# Additional OCSP verification with nonce
echo "Testing OCSP with nonce..."
openssl ocsp -issuer /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -cert /etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem \
    -text \
    -url $OCSP_URL \
    -header Host="$OCSP_HOST" \
    -verify_other /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -CAfile /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -nonce

# Pre-fetch and cache OCSP response
echo "Pre-fetching OCSP response..."
openssl ocsp -issuer /etc/nginx/ssl/ocsp-demo.rara.dev/chain.pem \
    -cert /etc/nginx/ssl/ocsp-demo.rara.dev/fullchain.pem \
    -url $OCSP_URL \
    -header Host="$OCSP_HOST" \
    -respout /tmp/ocsp-cache.der \
    -noverify

# Copy SSL configuration template
cp /etc/nginx/conf.d/ssl.conf.template /etc/nginx/conf.d/default.conf

# Debug: Test nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Start nginx with debug logging
echo "Starting Nginx with debug logging..."
nginx -g "daemon off;" &

# Start gunicorn
gunicorn app:app --bind 0.0.0.0:8000
