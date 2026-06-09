# Arduino CLI Configuration Script
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File "arduino_config.ps1"
# Run this after installing arduino-cli to set up ESP32 support.

param(
    [string]$sketch_path = "d:\esp32\arduino_projects"
)

Write-Output "=== Initializing Arduino CLI config ==="
arduino-cli config init

Write-Output "=== Adding ESP32 board URL ==="
arduino-cli config set board_manager.additional_urls "https://espressif.github.io/arduino-esp32/package_esp32_index.json"

Write-Output "=== Updating board index ==="
arduino-cli core update-index

Write-Output "=== Installing ESP32 core (this may take a while) ==="
arduino-cli config set network.connection_timeout 600s
arduino-cli core install esp32:esp32

Write-Output "=== Setting sketch directory ==="
arduino-cli config set directories.user $sketch_path

Write-Output "=== Verifying ==="
arduino-cli board listall | Select-String "esp32"
arduino-cli core list

Write-Output "=== Done ==="
Write-Output "ESP32 Arduino core installed. Sketch directory: $sketch_path"
