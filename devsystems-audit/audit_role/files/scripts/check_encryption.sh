#!/bin/bash

# Function to check encryption status and list unencrypted partitions
check_encryption() {
    encrypted=true
    unencrypted_partitions=()

    # List all block devices and check for encryption
    while IFS= read -r line; do
        device=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $2}')
        mountpoint=$(echo "$line" | awk '{print $3}')
        
        # Check if the type is 'crypt' (encrypted) or not
        if [[ "$type" != "crypt" && "$device" != loop* ]]; then
            encrypted=false
            unencrypted_partitions+=("$device($mountpoint)")
        fi
    done < <(lsblk -n -o NAME,TYPE,MOUNTPOINT --list | grep -v loop)

    # Display results
    if $encrypted; then
        echo "All partitions are encrypted."
        exit 0
    else
        echo -n "Some partitions are not encrypted(${#unencrypted_partitions[@]}): ${unencrypted_partitions[@]}" >&2
        exit 1
    fi
}

# Run the function
check_encryption
