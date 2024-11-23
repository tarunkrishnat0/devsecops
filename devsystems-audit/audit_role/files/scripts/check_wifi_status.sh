#!/bin/bash

# Extract output of 'nmcli general status'
general_status=$(nmcli general status)

# Parse general status into variables
read -r state connectivity wifi_hw wifi < <(echo "$general_status" | awk 'NR==2 {print $1, $2, $3, $4}')

# Extract and format the output of 'nmcli dev wifi list' into a JSON array
wifi_list=$(nmcli -t -f IN-USE,SSID,CHAN,SIGNAL dev wifi list | awk -F':' '{
  printf "{\"IN_USE\": \"%s\", \"SSID\": \"%s\", \"CHAN\": %s, \"Signal\": %s},", $1, $2, $3, $4;
}')

# Wrap the formatted JSON entries in brackets to create a valid JSON array
wifi_list=${wifi_list%?}
wifi_list="[$wifi_list]"

# Combine both outputs into a single JSON object
json=$(cat <<EOF
{
  "general_status": {
    "state": "$state",
    "connectivity": "$connectivity",
    "wifi_hw": "$wifi_hw",
    "wifi": "$wifi"
  },
  "wifi_list": $wifi_list
}
EOF
)

# Print the JSON in compact format
echo "$json" | jq -c -M .

if [[ $state == "connected" && $wifi_hw != "missing" ]];then
  exit 1
fi
