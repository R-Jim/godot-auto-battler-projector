#!/bin/bash
# Aggressive Godot process cleanup script

echo "Cleaning up all Godot processes..."

# Kill all Godot processes
pkill -9 -f "Godot" 2>/dev/null
pkill -9 -f "godot" 2>/dev/null

# Kill specific patterns
pkill -9 -f "Godot.*--headless" 2>/dev/null
pkill -9 -f "godot.*--headless" 2>/dev/null
pkill -9 -f "Godot.*--quit" 2>/dev/null

# Use killall as backup
killall -9 Godot 2>/dev/null
killall -9 godot 2>/dev/null

# Find and kill by process name
ps aux | grep -E "(Godot|godot)" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null

# On macOS, also check for app processes
if [[ "$OSTYPE" == "darwin"* ]]; then
    killall -9 "Godot" 2>/dev/null
    # Kill any Godot.app processes
    ps aux | grep "Godot.app" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
fi

echo "Cleanup complete"