#!/bin/bash

# Function to check if a user has sudo access
check_sudo() {
  local username=$1
  if groups "$username" | grep -qw "sudo"; then
    echo "true"
  else
    echo "false"
  fi
}

# Create arrays for sudo and non-sudo users
declare -a sudo_users
declare -a non_sudo_users

# Iterate through each user in /etc/passwd
while IFS=: read -r username _ uid gid _ home shell; do
  # Skip system users and users without a login shell
  if [[ $uid -ge 1000 && "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
    has_sudo=$(check_sudo "$username")
    if [[ $has_sudo == "true" ]]; then
      # Add to sudo users array
      sudo_users+=("{\"username\": \"$username\", \"shell\": \"$shell\"}")
    else
      # Add to non-sudo users array
      non_sudo_users+=("{\"username\": \"$username\", \"shell\": \"$shell\"}")
    fi
  fi
done < /etc/passwd

# Print JSON for sudo users to stderr
echo -n "{\"sudo_users\":[" >&2
echo -n "$(IFS=,; echo "${sudo_users[*]}")" >&2
echo -n "]}" >&2

# Print JSON for non-sudo users to stdout
echo -n "{\"non_sudo_users\":["
echo -n "$(IFS=,; echo "${non_sudo_users[*]}")"
echo -n "]}"
