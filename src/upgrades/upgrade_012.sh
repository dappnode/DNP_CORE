#!/bin/sh

# Upgrade from 0.2.58 to 0.2.59

# Ensure logs files have a smaller size than:
# - Scripts logs files 1MB: /usr/src/dappnode/logs/*.log
# - dappmanager userActionsLogs.json 4MB: /usr/src/dappnode/DNCORE/userActionLogs.json

max_log=1 # MB
max_json=4 # MB => Recommended size for JSON files to not break browsers https://www.joshzeigler.com/technology/web-development/how-big-is-too-big-for-json

logs_files=$(ls /usr/src/dappnode/logs/*.log)
json_file="/usr/src/dappnode/DNCORE/userActionLogs.json"

for file in $logs_files; do
  if [ $(du -m $file | cut -f1) -gt $max_log ]; then
    echo "Truncating $file"
    truncate -s 0 $file
  fi
done

if [ $(du -m $json_file | cut -f1) -gt $max_json ]; then
  echo "Truncating $json_file"
  truncate -s 0 $json_file
fi