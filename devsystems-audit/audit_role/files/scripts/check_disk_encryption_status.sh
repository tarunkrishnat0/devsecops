#!/bin/bash

# Function to get disk and partition information, including nested children
get_disk_info() {
  lsblk -J -o NAME,MOUNTPOINT,SIZE,TYPE,FSUSED | jq -c '
    def process_disk(device):
      {
        "name": device.name,
        "type": device.type,
        "mount_path": (if device.mountpoint == null then "unmounted" else device.mountpoint end),
        "size": device.size,
        "used_space": (if device.fsused == null then "unknown" else device.fsused end),
        "encrypted": (if device.name | test("crypt") then true else false end),
        "children": (if device.children then [device.children[] | process_disk(.)] else [] end)
      };
    [ .blockdevices[] | select(.type != "loop") | process_disk(.) ] | add
  '
}

# Process and output JSON
disks_json=$(get_disk_info)
echo "$disks_json"
