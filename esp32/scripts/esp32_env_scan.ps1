# ESP32 Environment Scanner & Recorder
# Purpose: Scan common locations for ESP-IDF installations, record findings.
# Usage: powershell -File esp32_env_scan.ps1
# Output: Creates esp32_env.json next to this script.

param(
    [switch]$ForceRescan
)

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$config_file = Join-Path $script_dir "esp32_env.json"

# If config exists and not forcing rescan, skip
if (-not $ForceRescan -and (Test-Path $config_file)) {
    Write-Output "=== Environment already configured ==="
    Get-Content $config_file | ConvertFrom-Json | ConvertTo-Json
    exit 0
}

Write-Output "=== Scanning for ESP-IDF ==="

# Scan common paths
$idf_search_paths = @(
    "$env:USERPROFILE\esp\esp-idf",
    "D:\esp32\esp-idf",
    "F:\work\esp32\esp-idf",
    "C:\esp-idf",
    "$env:USERPROFILE\esp-idf"
)

$IDF_PATH = $null
foreach ($p in $idf_search_paths) {
    if (Test-Path "$p\tools\idf.py") {
        $IDF_PATH = $p
        Write-Output "  Found ESP-IDF at: $IDF_PATH"
        break
    }
}

if (-not $IDF_PATH) {
    Write-Output "  ESP-IDF not found in common locations."
    Write-Output "  Please specify manually or run: git clone --recursive https://github.com/espressif/esp-idf.git <path>"
    $IDF_PATH = Read-Host "Enter ESP-IDF path (or press Enter to skip)"
    if (-not $IDF_PATH) {
        Write-Output "No ESP-IDF path provided. Run setup again later."
        exit 0
    }
}

Write-Output "=== Scanning for toolchain (.espressif) ==="
$tools_search_paths = @(
    "$env:USERPROFILE\.espressif",
    "$IDF_PATH\..\.espressif",
    "D:\esp32\.espressif",
    "F:\work\esp32\.espressif"
)

$IDF_TOOLS_PATH = $null
foreach ($p in $tools_search_paths) {
    if (Test-Path "$p\idf-env.json") {
        $IDF_TOOLS_PATH = $p
        Write-Output "  Found toolchain at: $IDF_TOOLS_PATH"
        break
    }
}

if (-not $IDF_TOOLS_PATH) {
    Write-Output "  Toolchain not found. Will be created during install.ps1"
    Write-Output "  Where should the toolchain be installed?"
    Write-Output "  Options:"
    Write-Output "    A) $env:USERPROFILE\.espressif (default, C drive)"
    Write-Output "    B) (Same parent as ESP-IDF)\.espressif"
    $choice = Read-Host "Choose [A/B] (default A)"
    if ($choice -eq "B" -or $choice -eq "b") {
        $IDF_TOOLS_PATH = Join-Path (Split-Path $IDF_PATH) ".espressif"
    } else {
        $IDF_TOOLS_PATH = "$env:USERPROFILE\.espressif"
    }
}

# Record to JSON
$env_config = @{
    idf_path = $IDF_PATH
    idf_tools_path = $IDF_TOOLS_PATH
    idf_python = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    idf_python_version = (python --version 2>&1)
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

$env_config | ConvertTo-Json -Depth 3 | Out-File -FilePath $config_file -Encoding UTF8

Write-Output "=== Environment recorded to: $config_file ==="
Write-Output ($env_config | ConvertTo-Json -Depth 3)
