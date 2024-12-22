FROM haproxy:2.8

USER root

# Install required packages
RUN apt-get update && \
    apt-get install -y \
        python3-venv \
        python3-pip \
        openssl \
        curl \
        && \
    rm -rf /var/lib/apt/lists/*

# Create and configure certbot virtual environment
RUN python3 -m venv /opt/certbot-dns && \
    . /opt/certbot-dns/bin/activate && \
    pip install certbot certbot-dns-route53 && \
    deactivate

# Download Mozilla's recommended DH parameters
RUN mkdir -p /etc/haproxy && \
    curl -sSLo /etc/haproxy/dhparams.pem https://ssl-config.mozilla.org/ffdhe2048.txt

# Copy configuration files
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY crt-list.txt /usr/local/etc/haproxy/crt-list.txt
COPY start.sh /usr/local/bin/start.sh

# Make start script executable
RUN chmod +x /usr/local/bin/start.sh

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/start.sh"]
