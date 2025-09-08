#!/bin/bash

# Run unit tests for Godot project
echo "Running Godot unit tests..."

# Check if Godot is in PATH
if ! command -v godot &> /dev/null; then
    echo "Error: Godot not found in PATH"
    echo "Please ensure Godot is installed and added to your PATH"
    exit 1
fi

# Run tests using GUT command line
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# Capture exit code
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "All tests passed!"
else
    echo "Tests failed with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE