#!/bin/bash
# Script to check node connectivity and health

# Input parameters
NODE_IP=$1
MAX_RETRIES=${2:-5}
RETRY_INTERVAL=${3:-10}

# Check if node IP is provided
if [ -z "$NODE_IP" ]; then
    echo "Error: Node IP address must be provided."
    echo "Usage: $0 <node-ip> [max-retries] [retry-interval]"
    exit 1
fi

echo "Checking connectivity to node $NODE_IP..."

# Try to ping the node
for i in $(seq 1 $MAX_RETRIES); do
    echo "Attempt $i of $MAX_RETRIES: Pinging $NODE_IP"
    if ping -c 1 -W 2 $NODE_IP &>/dev/null; then
        echo "Node $NODE_IP is responding to ping."
        
        # Check if SSH is available
        echo "Checking SSH connectivity..."
        if timeout 5 ssh -o StrictHostKeyChecking=no -o BatchMode=yes -o ConnectTimeout=5 k8s_80@$NODE_IP echo "SSH connection successful" &>/dev/null; then
            echo "SSH connection to $NODE_IP successful."
            exit 0
        else
            echo "SSH connection failed, but node is pingable."
            if [ $i -eq $MAX_RETRIES ]; then
                echo "Maximum retries reached. Node may need manual intervention."
                exit 2
            fi
        fi
    else
        echo "Node $NODE_IP is not responding to ping."
        if [ $i -eq $MAX_RETRIES ]; then
            echo "Maximum retries reached. Node may need manual intervention."
            exit 3
        fi
    fi
    
    echo "Waiting $RETRY_INTERVAL seconds before next attempt..."
    sleep $RETRY_INTERVAL
done

echo "Node health check completed with issues."
exit 1
