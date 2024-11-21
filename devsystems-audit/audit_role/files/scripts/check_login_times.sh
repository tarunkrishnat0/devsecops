#!/bin/bash

# Array to store user login times
declare -A user_logins

# Function to get the first system login after boot (UI login)
get_first_login() {
    user=$1
    last -F -i "$user" 2>/dev/null | grep -E " tty[0-9]+" | head -n 1 | awk '{for (i=4; i<=NF; i++) printf "%s ", $i; print ""}'
}

# Function to get the last SSH login and IP
get_ssh_login() {
    user=$1
    # Use last with -i to force IP addresses and filter SSH (pts/X)
    ssh_login=$(last -F -i "$user" 2>/dev/null | grep -E " pts/[0-9]+" | head -n 1)
    if [ -n "$ssh_login" ]; then
        # Extract the IP address (field $3) and all fields after $3 for login time
        ip_address=$(echo "$ssh_login" | awk '{print $3}')
        login_time=$(echo "$ssh_login" | awk '{for (i=4; i<=NF; i++) printf "%s ", $i; print ""}')
        echo "$login_time (IP: $ip_address)"
    else
        echo "Never logged in (SSH)"
    fi
}

# Get the list of all users from /etc/passwd
users=$(cut -d':' -f1 /etc/passwd)

# Iterate through each user
for user in $users; do
    # Skip system users without a shell
    shell=$(getent passwd "$user" | cut -d':' -f7)
    if [[ "$shell" != "/bin/bash" && "$shell" != "/bin/sh" && "$shell" != "/usr/bin/zsh" ]]; then
        continue
    fi

    # Retrieve the first system login after boot (UI login)
    first_ui_login=$(get_first_login "$user")
    if [ -z "$first_ui_login" ]; then
        first_ui_login="Never logged in (UI)"
    fi

    # Retrieve the last SSH login and IP address
    last_ssh_login=$(get_ssh_login "$user")

    # Append to the array in the format user:UI_login_time;SSH_login_time_and_IP
    # user_logins+=("$user:UI=$first_ui_login;SSH=$last_ssh_login")

    # Format login info as a JSON-like string
    login_info="{\"ssh-login\": \"$last_ssh_login\", \"ui-login\": \"$first_ui_login\"}"
    
    # Save result in the associative array
    user_logins["$user"]="$login_info"

done

# Get the last boot time
last_bootup=$(who -b | awk '{print $3, $4}')
last_reboot=$(last -x reboot -n1 | head -n1 | awk '{for (i=5; i<=NF; i++) printf "%s ", $i; print ""}')
last_shutdown=$(last -x shutdown -n1 | head -n1 | awk '{for (i=5; i<=NF; i++) printf "%s ", $i; print ""}')

# Start JSON output
echo -n "{"

echo -n "\"last_bootup\": \"$last_bootup\","
echo -n "\"last_reboot\": \"$last_reboot\","
echo -n "\"last_shutdown\": \"$last_shutdown\","

# Iterate over associative array and print as JSON
first_entry=true
for username in "${!user_logins[@]}"; do
  if [ "$first_entry" = true ]; then
    first_entry=false
  else
    echo -n ","
  fi
  echo -n "\"$username\": ${user_logins[$username]}"
done

# End JSON output
echo -n "}"