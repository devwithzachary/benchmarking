#!/bin/bash

OUTPUT_FILE="battery_life_$(hostname)_$(date +%Y%m%d_%H%M%S).csv"

# Find the battery directory (usually BAT0 or BAT1)
BAT_DIR=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n 1)

if [ -z "$BAT_DIR" ]; then
    echo "Error: No battery found in /sys/class/power_supply/"
    exit 1
fi

echo "Starting battery test..."
echo "Logging to: $OUTPUT_FILE"
echo "Date,Time,Elapsed,Battery,Status" > "$OUTPUT_FILE"

START_SEC=$(date +%s)

while true; do
    NOW_SEC=$(date +%s)
    ELAPSED_SEC=$((NOW_SEC - START_SEC))
    
    # Format elapsed time as HH:MM:SS
    ELAPSED_FMT=$(printf "%02d:%02d:%02d" $((ELAPSED_SEC/3600)) $((ELAPSED_SEC%3600/60)) $((ELAPSED_SEC%60)))
    
    DATE_FMT=$(date +"%Y-%m-%d,%H:%M:%S")
    CAPACITY=$(cat "$BAT_DIR/capacity" 2>/dev/null || echo "Unknown")
    STATUS=$(cat "$BAT_DIR/status" 2>/dev/null || echo "Unknown")
    
    # Write to file
    echo "$DATE_FMT,$ELAPSED_FMT,$CAPACITY%,$STATUS" >> "$OUTPUT_FILE"
    
    # Force flush to disk to prevent data loss on sudden power off
    sync
    
    # Wait 60 seconds before next check
    sleep 60
done
