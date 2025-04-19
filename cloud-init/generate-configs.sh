#!/bin/bash

# Script to generate cloud-init configuration files from templates

# Define node configurations
declare -A nodes
nodes=(
  ["k8s-node-1"]="k8s_80,192.168.1.80"
  ["k8s-node-2"]="k8s_81,192.168.1.81"
  ["k8s-node-3"]="k8s_82,192.168.1.82"
)

# SSH key generation or selection
generate_or_select_key() {
  echo "===== SSH Key Configuration ====="
  echo "This script will need an SSH key to configure access to your Kubernetes nodes."
  echo ""
  
  # Check for existing keys
  if [ -d "$HOME/.ssh" ] && [ "$(ls -A $HOME/.ssh/*.pub 2>/dev/null)" ]; then
    echo "Existing SSH public keys found:"
    ls -1 $HOME/.ssh/*.pub | nl
    echo ""
    echo "Would you like to use an existing key? [y/n]: "
    read use_existing
    
    if [[ "$use_existing" =~ ^[Yy] ]]; then
      echo "Enter the number of the key you'd like to use: "
      read key_number
      key_path=$(ls -1 $HOME/.ssh/*.pub | sed -n "${key_number}p")
      
      if [ -f "$key_path" ]; then
        SSH_KEY=$(cat "$key_path")
        SSH_KEY_PATH="${key_path%.pub}"
        echo "Selected key: $key_path"
        return 0
      else
        echo "Invalid selection. Will generate a new key."
      fi
    fi
  fi
  
  # Generate new key
  echo "Enter a name for your new SSH key (leave blank for default 'id_rsa'): "
  read key_name
  
  if [ -z "$key_name" ]; then
    key_name="id_rsa"
  fi
  
  # Check if key already exists
  if [ -f "$HOME/.ssh/$key_name" ]; then
    echo "A key with this name already exists. Do you want to use it? [y/n]: "
    read use_key
    
    if [[ "$use_key" =~ ^[Yy] ]]; then
      SSH_KEY=$(cat "$HOME/.ssh/$key_name.pub")
      SSH_KEY_PATH="$HOME/.ssh/$key_name"
      echo "Using existing key: $HOME/.ssh/$key_name.pub"
      return 0
    else
      echo "Please run the script again and choose a different key name."
      exit 1
    fi
  fi
  
  # Generate new key
  mkdir -p "$HOME/.ssh"
  ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/$key_name" -N "" -C "k8s_pi_cluster"
  SSH_KEY=$(cat "$HOME/.ssh/$key_name.pub")
  SSH_KEY_PATH="$HOME/.ssh/$key_name"
  echo "Generated new key: $HOME/.ssh/$key_name.pub"
}

# Call the function to set up SSH key
generate_or_select_key

# Create cloud-init-output directory if it doesn't exist
mkdir -p cloud-init-output

echo ""
echo "Generating cloud-init configurations for Kubernetes nodes..."

# Process each node
for node_name in "${!nodes[@]}"; do
  # Split the values
  IFS="," read -r username ip_address <<< "${nodes[$node_name]}"
  
  echo "Processing $node_name (User: $username, IP: $ip_address)"
  
  # Generate user-data file
  sed -e "s/__NODE_NAME__/$node_name/g" \
      -e "s/__USERNAME__/$username/g" \
      -e "s|__SSH_PUBLIC_KEY__|$SSH_KEY|g" \
      user-data.template > cloud-init-output/$node_name-user-data
  
  # Generate network-config file
  sed -e "s/__IP_ADDRESS__/$ip_address/g" \
      network-config.template > cloud-init-output/$node_name-network-config
  
  # Generate meta-data file
  sed -e "s/__NODE_NAME__/$node_name/g" \
      meta-data.template > cloud-init-output/$node_name-meta-data
done

echo ""
echo "Configuration files generated in the 'cloud-init-output' directory."
echo "To use them for a specific node, copy them to the boot partition:"
echo ""
echo "For example, for k8s-node-1:"
echo "cp cloud-init-output/k8s-node-1-user-data /path/to/boot/partition/user-data"
echo "cp cloud-init-output/k8s-node-1-network-config /path/to/boot/partition/network-config"
echo "cp cloud-init-output/k8s-node-1-meta-data /path/to/boot/partition/meta-data"
echo ""
echo "Remember to rename the files to user-data, network-config, and meta-data when copying to the boot partition."
echo ""
echo "SSH Key Information:"
echo "Private key path: $SSH_KEY_PATH"
echo "Use this key to log into your Kubernetes nodes after they boot."
echo "Example: ssh -i $SSH_KEY_PATH k8s_80@192.168.1.80"