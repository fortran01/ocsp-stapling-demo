# OCSP Stapling Demo

This project demonstrates OCSP stapling configuration using both Nginx and Apache with automated Let's Encrypt certificates and AWS Route53.

## Prerequisites

- Docker and Docker Compose installed locally
- AWS Route53 configured domain
- AWS credentials with Route53 access

## Project Structure

```plaintext
.
├── README.md           # Project documentation
├── docker-compose.yml  # Docker Compose configuration
├── nginx/             # Nginx configuration
│   ├── Dockerfile     # Nginx container configuration
│   ├── app.py         # Flask application
│   ├── conf.d/
│   │   └── ssl.conf.template  # SSL and OCSP configuration
│   ├── nginx.conf     # Main Nginx configuration
│   ├── ssl/          # SSL certificates directory
│   └── start.sh      # Certificate and Nginx startup script
└── apache/            # Apache configuration
    ├── Dockerfile    # Apache container configuration
    ├── conf/
    │   └── ssl.conf  # SSL and OCSP configuration
    ├── ssl/         # SSL certificates directory
    └── start.sh     # Certificate and Apache startup script
```

## Setup Instructions

1. Clone this repository

2. SSL certificates are automatically managed by Let's Encrypt:
   - Certificates are obtained using DNS-01 challenge via Route53
   - Certificate renewal is handled automatically
   - OCSP stapling is configured out of the box for both servers

3. Configure AWS credentials:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_SESSION_TOKEN

4. Start the application: (In Mac, `docker compose`)

   ```bash
   docker compose up --build
   ```

The startup scripts will:

- Check for existing SSL certificates
- Generate new certificates if needed using Let's Encrypt
- Configure servers with proper SSL settings
- Set up OCSP stapling
- Pre-fetch and cache OCSP responses

## Server Details

### Nginx Server

- Domain: ocsp-demo.rara.dev
- HTTP Port: 9080
- HTTPS Port: 9443

### Apache Server

- Domain: apache-ocsp.rara.dev
- HTTP Port: 8080
- HTTPS Port: 8443

## Testing OCSP Stapling

You can test OCSP stapling on either server using:

### For Nginx

```bash
echo QUIT | openssl s_client -connect ocsp-demo.rara.dev:9443 -status
```

### For Apache

```bash
echo QUIT | openssl s_client -connect apache-ocsp.rara.dev:8443 -status
```

The expected successful output should look like this:

```plaintext
CONNECTED(00000003)
OCSP response: 
======================================
OCSP Response Data:
    OCSP Response Status: successful (0x0)
    Response Type: Basic OCSP Response
    Version: 1 (0x0)
    Responder Id: C = US, O = Let's Encrypt, CN = E5
    Produced At: Dec 17 03:23:00 2024 GMT
    Responses:
    Certificate ID:
      Hash Algorithm: sha1
      Issuer Name Hash: 1E11C0C9ACFDA453EF4B2F6A732115604D54ADB9
      Issuer Key Hash: 99CD29C3A15826AF7A7A4C845A8F738860B0DFDE
      Serial Number: 030AA2B1A8A4718ADA9B33F81C280D26DD4B
    Cert Status: good
    This Update: Dec 17 03:23:00 2024 GMT
    Next Update: Dec 24 03:22:58 2024 GMT
