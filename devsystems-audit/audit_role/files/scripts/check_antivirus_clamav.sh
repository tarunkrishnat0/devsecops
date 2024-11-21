#!/bin/bash

# Check if ClamAV is installed (either clamscan or clamd)
if command -v clamscan &> /dev/null || command -v clamd &> /dev/null; then
    # echo "ClamAV is installed."

    # Check if the clamd service is running
    if systemctl is-active --quiet clamav-daemon; then
        echo "ClamAV is running."
    else
        echo "ClamAV is installed, but not running." >&2
        exit 1
    fi
else
    echo "ClamAV is not installed." >&2
    exit 1
fi
