#!/bin/bash

echo "Godot Path Configuration for MCP Server"
echo "======================================="
echo ""

# Function to test if a path is a valid Godot executable
test_godot_path() {
    if [ -x "$1" ]; then
        if "$1" --version 2>/dev/null | grep -q "Godot"; then
            return 0
        fi
    fi
    return 1
}

# Check if Godot is already in PATH
if command -v godot &> /dev/null; then
    echo "✓ Found Godot in PATH: $(which godot)"
    godot --version
    exit 0
fi

# Check common locations
echo "Checking common Godot locations..."

COMMON_PATHS=(
    "/Applications/Godot.app/Contents/MacOS/Godot"
    "/Applications/Godot_v4.app/Contents/MacOS/Godot"
    "/Applications/Godot4.app/Contents/MacOS/Godot"
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
    "/usr/local/bin/godot"
    "/opt/godot/godot"
)

for path in "${COMMON_PATHS[@]}"; do
    if test_godot_path "$path"; then
        echo "✓ Found Godot at: $path"
        echo ""
        echo "To use this Godot installation with MCP, add to your shell profile:"
        echo "export GODOT_PATH=\"$path\""
        echo ""
        echo "Or create a symlink:"
        echo "sudo ln -s \"$path\" /usr/local/bin/godot"
        exit 0
    fi
done

# If not found, provide instructions
echo "✗ Godot not found in common locations"
echo ""
echo "Please install Godot 4.x from: https://godotengine.org/download"
echo ""
echo "After installation, you can:"
echo "1. Add Godot to your PATH"
echo "2. Set GODOT_PATH environment variable"
echo "3. Run this script again to detect the installation"
echo ""
echo "If Godot is installed in a custom location, set:"
echo "export GODOT_PATH=\"/path/to/your/godot/executable\""