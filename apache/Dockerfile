FROM httpd:2.4

# Install required packages
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    openssl \
    awscli \
    dnsutils \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set up certbot with Route53 plugin
RUN python3 -m venv /opt/certbot-dns/ \
    && . /opt/certbot-dns/bin/activate \
    && pip install certbot certbot-dns-route53 \
    && deactivate

# Enable required Apache modules
RUN sed -i 's/#LoadModule ssl_module/LoadModule ssl_module/' /usr/local/apache2/conf/httpd.conf \
    && sed -i 's/#LoadModule socache_shmcb_module/LoadModule socache_shmcb_module/' /usr/local/apache2/conf/httpd.conf \
    && sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /usr/local/apache2/conf/httpd.conf

# Include SSL configuration
RUN echo "Include conf/extra/ssl.conf" >> /usr/local/apache2/conf/httpd.conf

# Copy SSL configuration
COPY conf/ssl.conf /usr/local/apache2/conf/extra/ssl.conf

# Copy start script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
