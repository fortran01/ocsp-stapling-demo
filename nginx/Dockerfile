FROM nginx:mainline-alpine

# Install Python and other dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    openssl \
    py3-flask \
    py3-gunicorn \
    certbot \
    certbot-nginx \
    aws-cli \
    bind-tools \
    curl

# Create necessary directories
RUN mkdir -p /var/www/certbot \
    /etc/nginx/ssl/ocsp-demo.rara.dev \
    /etc/nginx/conf.d \
    /tmp/nginx \
    /etc/letsencrypt \
    && chown -R nginx:nginx \
        /etc/nginx/ssl \
        /var/www/certbot \
        /etc/nginx/conf.d \
        /tmp/nginx \
        /etc/letsencrypt \
    && chmod -R 750 /etc/nginx/ssl

# Create a virtual environment for certbot plugins
RUN python3 -m venv /opt/certbot-dns
ENV PATH="/opt/certbot-dns/bin:$PATH"
RUN . /opt/certbot-dns/bin/activate && \
    pip3 install certbot-dns-route53 && \
    deactivate

# Generate DH parameters (2048 bits for faster generation in demo)
RUN openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ssl.conf.template /etc/nginx/conf.d/default.conf

# Copy application code and startup script
COPY app.py /app/
COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /app

# Expose ports
EXPOSE 80 443

# Start Nginx and Gunicorn
CMD ["/start.sh"]
