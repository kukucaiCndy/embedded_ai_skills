# ESP32 Chip Detection Script
param(
    [string]$port = "COM11"
)

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$config_file = Join-Path $script_dir "esp32_env.json"

if (-not (Test-Path $config_file)) {
    Write-Error "esp32_env.json not found."
    exit 1
}

$config = Get-Content $config_file | ConvertFrom-Json
$env:IDF_PATH = $config.idf_path
$env:IDF_TOOLS_PATH = $config.idf_tools_path

# Clear MSYS2
[Environment]::SetEnvironmentVariable("MSYSTEM", $null, "Process")
[Environment]::SetEnvironmentVariable("MSYS2_PATH", $null, "Process")

Set-Location $env:IDF_PATH
& .\export.ps1 | Out-Null

Write-Host "Chip: ESP32-S3, Port: $port"
python -m esptool --port $port --chip esp32s3 --before default-reset --after hard-reset flash-id
