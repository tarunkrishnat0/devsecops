#!/bin/bash

# Directory to check
SSH_DIR="$HOME/.ssh"

# Function to check if a key has a passphrase
check_passphrase() {
    ssh-keygen -y -f "$1" </dev/null >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo false
    else
        echo true
    fi
}

# Initialize JSON output
output="{"

# Find all files in the .ssh directory and subdirectories
while IFS= read -r file; do
    if [[ -f "$file" ]]; then
        # Check if the file is a private key
        if grep -q "PRIVATE KEY" "$file"; then
            # Get key details
            algorithm=$(ssh-keygen -l -f "$file" 2>/dev/null | awk '{print $4}')
            bits=$(ssh-keygen -l -f "$file" 2>/dev/null | awk '{print $1}')
            has_passphrase=$(check_passphrase "$file")
            created_date=$(stat -c '%y' "$file" 2>/dev/null | awk '{print $1}')
            
            # Determine if the key meets requirements
            if [[ (($algorithm == "(RSA)" && $bits -eq 4096) || $algorithm == "(ED25519)") && $has_passphrase == true ]]; then
                status="valid"
            else
                status="invalid"
            fi

            # Add to JSON output
            output+="\"$file\": {"
            output+="\"algorithm\": \"$algorithm\", "
            output+="\"bits\": \"$bits\", "
            output+="\"has_passphrase\": $has_passphrase, "
            output+="\"created_date\": \"$created_date\", "
            output+="\"status\": \"$status\"}, "
        fi
    fi
done < <(find "$SSH_DIR" -type f)

# Remove trailing comma and close JSON object
output=${output%, }
output+="}"

# Print JSON output
echo -n "$output"
