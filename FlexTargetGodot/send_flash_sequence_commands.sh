#!/bin/bash

# BLE Flash Sequence Commands - cURL Examples
# 
# This script contains cURL commands to trigger the flash_sequence animation
# Run each command individually or source this file and call functions
#
# Usage:
#   bash send_flash_sequence_commands.sh
#   # or
#   source send_flash_sequence_commands.sh
#   ready_command
#   animation_config_command
#   start_command
#   end_command

# Configuration
SERVER_HOST="${SERVER_HOST:-localhost}"
SERVER_PORT="${SERVER_PORT:-80}"
PROTOCOL="${PROTOCOL:-http}"
ENDPOINT="${ENDPOINT:-/test/ble}"
URL="${PROTOCOL}://${SERVER_HOST}:${SERVER_PORT}${ENDPOINT}"
TIMEOUT="${TIMEOUT:-30}"
DELAY="${DELAY:-0}"

echo "=========================================="
echo "BLE Flash Sequence Commands"
echo "=========================================="
echo "Server: $URL"
echo "Timeout: ${TIMEOUT}s"
echo "Delay: ${DELAY}s"
echo "=========================================="

# 1. Ready Command - Prepare the system
ready_command() {
  echo ""
  echo ">>> Sending Ready Command..."
  curl -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d '{
      "action": "netlink_forward",
      "content": {
        "command": "ready",
        "mode": "cqb",
        "targetType": "disguised_enemy"
      },
      "dest": "A"
    }' \
    -w "\nHTTP Status: %{http_code}\n"
  echo ""
}

# 2. Animation Config Command - Set the flash_sequence animation
animation_config_command() {
  echo ""
  echo ">>> Sending Animation Config Command (disguised_enemy_flash)..."
  curl -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d '{
      "action": "netlink_forward",
      "content": {
        "command": "animation_config",
        "action": "disguised_enemy_flash",
        "duration": -1.0
      },
      "dest": "A"
    }' \
    -w "\nHTTP Status: %{http_code}\n"
  echo ""
}

# 3. Start Command - Begin the drill with animation
start_command() {
  echo ""
  echo ">>> Sending Start Command..."
  curl -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"action\": \"netlink_forward\",
      \"content\": {
        \"command\": \"start\",
        \"mode\": \"cqb\",
        \"targetType\": \"disguised_enemy\",
        \"timeout\": ${TIMEOUT},
        \"delay\": ${DELAY}
      },
      \"dest\": \"A\"
    }" \
    -w "\nHTTP Status: %{http_code}\n"
  echo ""
}

# 4. End Command - Complete the drill
end_command() {
  echo ""
  echo ">>> Sending End Command..."
  curl -X POST "$URL" \
    -H "Content-Type: application/json" \
    -d '{
      "action": "netlink_forward",
      "content": {
        "command": "end"
      },
      "dest": "A"
    }' \
    -w "\nHTTP Status: %{http_code}\n"
  echo ""
}

# Run the complete sequence
complete_sequence() {
  ready_command
  echo "Waiting 1 second..."
  sleep 1
  
  animation_config_command
  echo "Waiting 1 second..."
  sleep 1
  
  start_command
  
  # Wait for animation to complete
  ANIMATION_DURATION=6  # 3s + 3s
  WAIT_TIME=$((ANIMATION_DURATION + DELAY + 2))
  echo "Waiting ${WAIT_TIME}s for animation to complete..."
  sleep ${WAIT_TIME}
  
  end_command
  
  echo "=========================================="
  echo "✓ All commands sent successfully!"
  echo "=========================================="
}

# If script is executed directly (not sourced), run the complete sequence
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  complete_sequence
fi
