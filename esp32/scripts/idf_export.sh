#!/bin/bash
# ESP-IDF Environment Export Script (Linux/macOS)
# Reads paths from esp32_env.json
# Usage: source ./idf_export.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/esp32_env.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: esp32_env.json not found. Run esp32_env_scan.sh first."
    exit 1
fi

IDF_PATH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['idf_path'])")
IDF_TOOLS_PATH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['idf_tools_path'])")

export IDF_PATH
export IDF_TOOLS_PATH

cd "$IDF_PATH" || exit 1
source ./export.sh
