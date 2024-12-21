FROM haproxy:2.8

USER root

# Install required packages
RUN apt-get update && apt-get install -y \
    openssl \
    curl \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install certbot with Route53 plugin
RUN python3 -m venv /opt/certbot-dns \
    && . /opt/certbot-dns/bin/activate \
    && pip install certbot certbot-dns-route53 \
    && deactivate

# Create directories
RUN mkdir -p /etc/haproxy/ssl /usr/local/etc/haproxy/certs

# Copy configuration and scripts
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Use Mozilla's recommended DH parameters instead of generating our own
RUN curl -sSLo /etc/haproxy/dhparams.pem https://ssl-config.mozilla.org/ffdhe2048.txt

ENTRYPOINT ["/start.sh"]
