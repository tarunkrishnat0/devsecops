#!/bin/bash

# Initialize JSON string
json="{"

# Iterate over each line of IP address information
while IFS= read -r line; do
  # Extract interface name and IP address
  iface=$(echo "$line" | awk '{print $2}' | tr -d ':')
  ip=$(echo "$line" | awk '{print $4}' | cut -d'/' -f1)

  # Append to JSON if iface and IP are non-empty
  if [[ -n "$iface" && -n "$ip" ]]; then
    json+="\"$iface\":\"$ip\","
  fi
done < <(ip -o -4 addr show | grep -vwE "lo|docker|virbr")

# Remove the trailing comma and close JSON
json="${json%,}}"

# Print JSON
echo "$json"
