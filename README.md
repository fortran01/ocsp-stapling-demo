# OCSP Stapling Demo

This project demonstrates OCSP stapling configuration using Nginx with automated Let's Encrypt certificates and AWS Route53.

## Prerequisites

- Docker and Docker Compose installed locally
- AWS Route53 configured domain
- AWS credentials with Route53 access

## Project Structure

```plaintext
.
├── README.md           # Project documentation
├── deploy-local.sh     # Local deployment script
├── docker-compose.yml  # Docker Compose configuration
└── nginx/
    ├── Dockerfile     # Nginx container configuration
    ├── app.py         # Flask application
    ├── conf.d/
    │   └── ssl.conf.template  # SSL and OCSP configuration
    ├── nginx.conf     # Main Nginx configuration
    ├── ssl/          # SSL certificates directory
    └── start.sh      # Certificate and Nginx startup script
```

## Setup Instructions

1. Clone this repository

2. SSL certificates are automatically managed by Let's Encrypt:
   - Certificates are obtained using DNS-01 challenge via Route53
   - Certificate renewal is handled automatically
   - OCSP stapling is configured out of the box

3. Configure AWS credentials:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - AWS_SESSION_TOKEN

4. Start the application:

   ```bash
   docker-compose up --build
   ```

The startup script will:

- Check for existing SSL certificates
- Generate new certificates if needed using Let's Encrypt
- Configure Nginx with proper SSL settings
- Set up OCSP stapling

## Testing OCSP Stapling

You can test OCSP stapling using:

```bash
echo QUIT | openssl s_client -connect ocsp-demo.rara.dev:9443 -status
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
