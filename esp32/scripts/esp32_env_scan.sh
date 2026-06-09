#!/bin/bash
# ESP32 Environment Scanner (Linux/macOS)
# Scans common locations for ESP-IDF, records findings to esp32_env.json

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/esp32_env.json"

if [ -f "$CONFIG_FILE" ] && [ "$1" != "--force" ]; then
    echo "=== Environment already configured ==="
    cat "$CONFIG_FILE"
    exit 0
fi

echo "=== Scanning for ESP-IDF ==="

IDF_SEARCH_PATHS=(
    "$HOME/esp/esp-idf"
    "/opt/esp-idf"
    "$HOME/esp-idf"
    "$HOME/esp32/esp-idf"
)

IDF_PATH=""
for p in "${IDF_SEARCH_PATHS[@]}"; do
    if [ -f "$p/tools/idf.py" ]; then
        IDF_PATH="$p"
        echo "  Found ESP-IDF at: $IDF_PATH"
        break
    fi
done

if [ -z "$IDF_PATH" ]; then
    echo "  ESP-IDF not found in common locations."
    read -p "Enter ESP-IDF path (or press Enter to skip): " IDF_PATH
    if [ -z "$IDF_PATH" ]; then
        echo "No ESP-IDF path provided."
        exit 0
    fi
fi

echo "=== Scanning for toolchain (.espressif) ==="
TOOLS_SEARCH_PATHS=(
    "$HOME/.espressif"
    "$(dirname "$IDF_PATH")/.espressif"
)

IDF_TOOLS_PATH=""
for p in "${TOOLS_SEARCH_PATHS[@]}"; do
    if [ -f "$p/idf-env.json" ]; then
        IDF_TOOLS_PATH="$p"
        echo "  Found toolchain at: $IDF_TOOLS_PATH"
        break
    fi
done

if [ -z "$IDF_TOOLS_PATH" ]; then
    echo "  Toolchain not found."
    echo "  Where to install?"
    echo "    A) $HOME/.espressif (default)"
    echo "    B) $(dirname "$IDF_PATH")/.espressif"
    read -p "Choose [A/B] (default A): " choice
    if [ "$choice" = "B" ] || [ "$choice" = "b" ]; then
        IDF_TOOLS_PATH="$(dirname "$IDF_PATH")/.espressif"
    else
        IDF_TOOLS_PATH="$HOME/.espressif"
    fi
fi

# Detect OS
case "$(uname -s)" in
    Linux*)  PLATFORM="linux" ;;
    Darwin*) PLATFORM="macos" ;;
    *)       PLATFORM="unknown" ;;
esac

# Write config
cat > "$CONFIG_FILE" << EOF
{
  "idf_path": "$IDF_PATH",
  "idf_tools_path": "$IDF_TOOLS_PATH",
  "idf_python": "$(which python3 || which python)",
  "idf_python_version": "$(python3 --version 2>&1 || python --version 2>&1)",
  "platform": "$PLATFORM",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF

echo "=== Environment recorded to: $CONFIG_FILE ==="
cat "$CONFIG_FILE"
