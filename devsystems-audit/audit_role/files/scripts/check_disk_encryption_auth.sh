#!/bin/bash

# Check if the cryptsetup command is available
if ! command -v cryptsetup &> /dev/null; then
    echo "Error: cryptsetup is not installed. Please install it and try again."
    exit 1
fi

# Get all block devices and their partitions
PARTITIONS=$(lsblk -rno NAME,TYPE | awk '$2 == "part" { print "/dev/"$1 }')

# Start JSON output
echo -n "["

first_partition=true

# Iterate over each partition
for PARTITION in $PARTITIONS; do
    # Check if the partition is a LUKS-encrypted device
    if cryptsetup isLuks "$PARTITION" &> /dev/null; then
        if ! $first_partition; then
            echo -n ","
        fi
        first_partition=false

        # Start JSON for the current partition
        echo -n "{"
        echo -n "  \"partition\": \"$PARTITION\","
        echo -n "  \"details\": "

        cryptsetup luksDump --dump-json-metadata "$PARTITION" | jq -c -M '{tokens, keyslots} | .tokens |= with_entries(.value |= del(.["fido2-credential"], .["fido2-salt"])) | .keyslots |= map_values(del(.area, .kdf))'
        echo -n "}"
    fi
done

# End JSON output
echo -n "]"
