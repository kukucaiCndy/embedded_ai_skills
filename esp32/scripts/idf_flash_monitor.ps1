# ESP-IDF Flash & Monitor Script (Generic)
# Reads paths from esp32_env.json
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File "idf_flash_monitor.ps1" -project_path <path> -com_port COM3

param(
    [string]$project_path = ".",
    [string]$com_port = "COM3"
)

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$config_file = Join-Path $script_dir "esp32_env.json"

if (-not (Test-Path $config_file)) {
    Write-Error "esp32_env.json not found. Run esp32_env_scan.ps1 first."
    exit 1
}

$config = Get-Content $config_file | ConvertFrom-Json
$env:IDF_PATH = $config.idf_path
$env:IDF_TOOLS_PATH = $config.idf_tools_path

[Environment]::SetEnvironmentVariable("MSYSTEM", $null, 'Process')
[Environment]::SetEnvironmentVariable("MSYS2_PATH", $null, 'Process')

# Export environment
Set-Location $env:IDF_PATH
& .\export.ps1

# Flash and monitor
Set-Location $project_path
Write-Output "=== Flashing to $com_port ==="
idf.py -p $com_port flash monitor
