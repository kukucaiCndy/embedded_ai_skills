# ESP-IDF OpenOCD Launch Script for ESP32-S3 builtin USB-JTAG

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

$openocd_exe = Join-Path $config.idf_tools_path "tools\openocd-esp32\v0.12.0-esp32-20260424\openocd-esp32\bin\openocd.exe"
$script_path = Join-Path $config.idf_tools_path "tools\openocd-esp32\v0.12.0-esp32-20260424\openocd-esp32\share\openocd\scripts"

Write-Host "=== Starting OpenOCD for ESP32-S3 ==="
Write-Host "Device: USB JTAG/serial debug unit (libusb0)"
Write-Host "Config: board/esp32s3-builtin.cfg"
Write-Host ""

& $openocd_exe -s $script_path -f board/esp32s3-builtin.cfg -d2
