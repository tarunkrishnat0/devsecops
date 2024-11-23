#!/bin/bash

# Function to check if a file is an SSH key
is_ssh_key() {
  local key_path=$1
  if [[ -f "$key_path" ]]; then
    local header=$(head -n 1 "$key_path")
    if [[ "$header" =~ ^-----BEGIN\ (OPENSSH|RSA|EC|DSA|ED25519)\ PRIVATE\ KEY-----$ ]]; then
      echo "true"
    else
      echo "false"
    fi
  else
    echo "false"
  fi
}

# Function to check if a key has a passphrase
check_passphrase() {
  local key_path=$1
  if ssh-keygen -y -P "" -f "$key_path" >/dev/null 2>&1; then
    echo "false"
  else
    echo "true"
  fi
}

# Function to extract key algorithm and size
get_key_info() {
  local key_path=$1
  local info
  info=$(ssh-keygen -lf "$key_path" 2>/dev/null)
  local size=$(echo "$info" | awk '{print $1}')
  local algo=$(echo "$info" | awk '{print $4}')
  echo "$size;$algo"
}

# Function to determine if the key is valid
is_key_valid() {
  local size=$1
  local algo=$2
  local has_passphrase=$3
  if [[ (($algo == "(RSA)" && $size -eq 4096) || $algo == "(ED25519)") && $has_passphrase == true ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Function to get file creation and modification times
get_file_timestamps() {
  local key_path=$1
  local created=$(stat -c %w "$key_path" 2>/dev/null || echo "N/A") # Creation time
  local modified=$(stat -c %y "$key_path") # Modification time
  echo "$created;$modified"
}

# Create arrays for users and their details
declare -a user_status
declare -a ssh_key_status
has_key_without_passphrase="false"

# Iterate through each user in /etc/passwd
while IFS=: read -r username _ uid gid _ home shell; do
  # Skip system users and users without a login shell
  if [[ $uid -ge 1000 && "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
    has_sudo=$(groups "$username" | grep -qw "sudo" && echo "true" || echo "false")

    # Check for .ssh directory
    ssh_dir="$home/.ssh"
    if [[ -d "$ssh_dir" ]]; then
      # Find all private keys in the .ssh directory
      for key in "$ssh_dir"/*; do
        if [[ -f "$key" && $(is_ssh_key "$key") == "false" ]]; then
          continue # Check only OPENSSH Private key files
        fi
        if [[ -f "$key" ]]; then
          has_passphrase=$(check_passphrase "$key")
          key_info=$(get_key_info "$key")
          key_size=$(echo "$key_info" | cut -d';' -f1)
          key_algo=$(echo "$key_info" | cut -d';' -f2)
          valid_key=$(is_key_valid "$key_size" "$key_algo" "$has_passphrase")
          timestamps=$(get_file_timestamps "$key")
          created=$(echo "$timestamps" | cut -d';' -f1)
          modified=$(echo "$timestamps" | cut -d';' -f2)

          ssh_key_status+=("{\"path\": \"$key\", \"valid\": $valid_key, \"has_passphrase\": $has_passphrase, \"algorithm\": \"$key_algo\", \"size\": $key_size, \"created\": \"$created\", \"modified\": \"$modified\"}")
        
          # Check if the key does not have a passphrase
          if [[ $has_passphrase == "false" ]]; then
            has_key_without_passphrase="true"
          fi
        fi
      done
    fi

    # Add user details to JSON
    user_status+=("{\"username\": \"$username\", \"sudo\": $has_sudo, \"shell\": \"$shell\", \"ssh_keys\": [$(IFS=,; echo "${ssh_key_status[*]}")]}")
    ssh_key_status=() # Clear ssh_key_status for the next user
  fi
done < /etc/passwd

# Print the JSON output
output="[ $(IFS=,; echo "${user_status[*]}") ]"

if [[ $has_key_without_passphrase == "true" ]]; then
  echo "$output" >&2 # Print to stderr if any key lacks a passphrase
  exit 1
else
  echo "$output" # Print to stdout otherwise
  exit 0
fi