#!/bin/bash

echo "Starting test loop check..."
echo "Running a single test file with monitoring..."

# Start Godot test in background
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gtest=test_gut_setup.gd -gexit > test_output.log 2>&1 &
PID=$!

echo "Started Godot with PID: $PID"

# Monitor for 30 seconds
for i in {1..30}; do
    if ! kill -0 $PID 2>/dev/null; then
        echo "Process completed after $i seconds"
        wait $PID
        EXIT_CODE=$?
        echo "Exit code: $EXIT_CODE"
        echo "Output:"
        cat test_output.log
        exit 0
    fi
    echo "Still running after $i seconds..."
    sleep 1
done

echo "Process still running after 30 seconds - likely stuck in a loop"
echo "Killing process..."
kill -9 $PID 2>/dev/null
echo "Process killed"
echo "Output so far:"
cat test_output.log