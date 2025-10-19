#!/bin/sh

# Enhanced API server health check script for keepalived
# This script checks multiple endpoints to verify API server health

APISERVER_VIP="192.168.1.100"
APISERVER_DEST_PORT="6443"
MAX_RETRIES=3
RETRY_INTERVAL=2

errorExit() {
    echo "*** $*" 1>&2
    exit 1
}

# Function to check an endpoint with retries
checkEndpoint() {
    local endpoint=$1
    local retry=0
    
    while [ $retry -lt $MAX_RETRIES ]; do
        if curl --silent --max-time 2 --insecure "https://$endpoint/" -o /dev/null; then
            echo "Endpoint $endpoint is healthy"
            return 0
        fi
        retry=$((retry+1))
        sleep $RETRY_INTERVAL
    done
    
    errorExit "Error: API server at $endpoint is not healthy after $MAX_RETRIES retries"
}

# Check local API server direct endpoint (internal port)
checkEndpoint "localhost:6444"

# Check VIP endpoint (external port)
checkEndpoint "${APISERVER_VIP}:${APISERVER_DEST_PORT}"

# If we get here, both checks passed
exit 0
