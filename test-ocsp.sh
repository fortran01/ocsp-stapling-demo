#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

test_ocsp() {
    local server=$1
    local port=$2
    
    echo -e "${BLUE}Testing OCSP stapling for $server on port $port...${NC}"
    echo "----------------------------------------"
    
    output=$(echo QUIT | openssl s_client -connect "$server:$port" -status 2>&1)
    
    if echo "$output" | grep -q "OCSP Response Status: successful"; then
        echo -e "${GREEN}✓ OCSP stapling is working${NC}"
    else
        echo "❌ OCSP stapling might not be working properly"
    fi
    
    echo "$output" | grep -A 15 "OCSP response:"
    echo -e "\n"
}

# Test all servers
test_ocsp "ocsp-demo.rara.dev" "9443"    # Nginx
test_ocsp "apache-ocsp.rara.dev" "8443"   # Apache
test_ocsp "haproxy-ocsp.rara.dev" "7443"  # HAProxy
