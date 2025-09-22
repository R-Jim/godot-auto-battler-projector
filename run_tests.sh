#!/bin/bash

# Run unit tests for Godot project with cleanup
echo "Running Godot unit tests..."

LOG_DIR="${LOG_DIR:-$(pwd)/.godot_logs}"
mkdir -p "$LOG_DIR"

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up Godot processes..."
    pkill -9 -f "Godot.*--headless" 2>/dev/null
    pkill -9 -f "godot.*--headless" 2>/dev/null
    # Also cleanup any zombie processes
    killall -9 Godot 2>/dev/null
}

# Set trap to cleanup on script exit
trap cleanup EXIT INT TERM

# Check if Godot is in PATH
if ! command -v godot &> /dev/null; then
    echo "Error: Godot not found in PATH"
    echo "Please ensure Godot is installed and added to your PATH"
    exit 1
fi

# Run tests using GUT command line with additional flags
# Note: macOS doesn't have timeout by default, so we'll use a background process
# --quit-after 1 ensures Godot exits after one frame when tests complete
godot --headless --log-file "$LOG_DIR/godot-test.log" --quit-after 1 -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit &
GODOT_PID=$!

# Wait for process or timeout
SECONDS=0
while kill -0 $GODOT_PID 2>/dev/null; do
    if [ $SECONDS -ge 120 ]; then
        echo "Test timeout reached (120 seconds)"
        kill -9 $GODOT_PID 2>/dev/null
        wait $GODOT_PID 2>/dev/null
        EXIT_CODE=124
        break
    fi
    sleep 1
done

# Get exit code if process finished normally
if [ -z "$EXIT_CODE" ]; then
    wait $GODOT_PID
    EXIT_CODE=$?
fi

# Give a moment for process to exit cleanly
sleep 1

# Force cleanup
cleanup

if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed!"
elif [ $EXIT_CODE -eq 124 ]; then
    echo "Tests timed out after 120 seconds"
    EXIT_CODE=1
else
    echo "Tests failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
