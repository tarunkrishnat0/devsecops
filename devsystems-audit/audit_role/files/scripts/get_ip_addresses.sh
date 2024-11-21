#!/bin/bash

# Initialize an array to store interface:IP entries
interfaces_ips=()

# Iterate over all network interfaces (ignores loopback and inactive interfaces)
for interface in $(ip -o link show | awk -F': ' '{print $2}' | grep -vE "lo|virbr|docker"); do
    # Get the IP address associated with the interface
    ip_address=$(ip addr show "$interface" | grep -w inet | awk '{print $2}' | cut -d/ -f1)
    
    # If the interface has an IP address, store it in the array
    if [ -n "$ip_address" ]; then
        interfaces_ips+=("$interface:$ip_address")
    fi
done

# Print the results
echo "Interfaces and IP addresses (${#interfaces_ips[@]}): ${interfaces_ips[@]}"

exit 0
