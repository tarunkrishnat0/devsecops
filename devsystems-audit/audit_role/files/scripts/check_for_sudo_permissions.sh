#!/bin/bash

# Initialize arrays to store users
users_with_sudo=()
users_without_sudo=()

# Check only regular login-capable users (UID >= 1000, valid shell, and non-empty home directory)
while IFS=: read -r username _ uid _ _ home shell; do
    if [[ "$uid" -ge 1000 && "$username" != "nobody" && "$shell" != "/sbin/nologin" && "$shell" != "/bin/false" && -n "$home" ]]; then
        if sudo -l -U "$username" 2>/dev/null | grep -q "(ALL) ALL"; then
            users_with_sudo+=("$username")
        else
            users_without_sudo+=("$username")
        fi
    fi
done < /etc/passwd

# Print users with sudo permissions
echo -n "Users with sudo permissions(${#users_with_sudo[@]}): ${users_with_sudo[@]}"

# Print users without sudo permissions
echo -n " AND Users without sudo permissions(${#users_without_sudo[@]}): ${users_without_sudo[@]}"

if [ ${#users_without_sudo[@]} -ge 1 ]; then
    exit 0
else
    exit 1
fi