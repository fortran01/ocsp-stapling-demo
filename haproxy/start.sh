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

# Copy certificate list file to HAProxy config directory
cp /usr/local/etc/haproxy/crt-list.txt /etc/haproxy/crt-list.txt

# Create .ocsp directory for HAProxy
mkdir -p /etc/haproxy/ssl/${DOMAIN}/.ocsp
OCSP_FILE="/etc/haproxy/ssl/${DOMAIN}/.ocsp/combined.pem.ocsp"

# Get OCSP response
echo "Getting initial OCSP response..."

# Get OCSP responder URL
OCSP_URL=$(openssl x509 -in /etc/haproxy/ssl/${DOMAIN}/fullchain.pem -noout -ocsp_uri)
echo "OCSP URL: ${OCSP_URL}"

# Get OCSP response
openssl ocsp -no_nonce \
    -issuer /etc/haproxy/ssl/${DOMAIN}/chain.pem \
    -cert /etc/haproxy/ssl/${DOMAIN}/fullchain.pem \
    -url "${OCSP_URL}" \
    -header "Host=e6.o.lencr.org" \
    -respout "${OCSP_FILE}" \
    -verify_other /etc/haproxy/ssl/${DOMAIN}/chain.pem \
    -CAfile /etc/haproxy/ssl/${DOMAIN}/chain.pem \
    -text

if [ $? -eq 0 ]; then
    echo "OCSP response obtained successfully"
    ls -l "${OCSP_FILE}"
    echo "OCSP response contents:"
    openssl ocsp -respin "${OCSP_FILE}" -text -noverify
    chmod 644 "${OCSP_FILE}"
    # Create a symlink in the same directory as the certificate
    ln -sf "${OCSP_FILE}" "/etc/haproxy/ssl/${DOMAIN}/combined.pem.ocsp"
else
    echo "Failed to get OCSP response"
    exit 1
fi

# Start HAProxy in master-worker mode with debug output
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg -W -d
