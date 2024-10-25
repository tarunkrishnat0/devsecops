#!/bin/bash

exit_value=0
# Loop through each user in the /etc/passwd file
while IFS=: read -r user _ _ _ _ home shell; do
    # Check if the user has a valid shell (e.g., /bin/bash, /bin/sh, etc.)
    if [[ "$user" == dw-admin || "$user" == root ]]; then
        continue
    fi
    if [[ "$shell" == /bin/bash || "$shell" == /bin/sh || "$shell" == /bin/zsh ]]; then
        if id -u "$user" >/dev/null 2>&1; then
            # Check if the user has sudo privileges
            if sudo -l -U "$user" | grep -q '(ALL : ALL) ALL'; then
                echo "$user has sudo permissions."
                exit_value=1
            else
                echo "$user does not have sudo permissions."
            fi
        else
            echo "$user does not exist."
        fi
    fi
done < /etc/passwd

exit $exit_value