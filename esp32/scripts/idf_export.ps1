# ESP-IDF Environment Export Script (Generic)
# Reads paths from esp32_env.json in the same directory as this script
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File "idf_export.ps1"

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$config_file = Join-Path $script_dir "esp32_env.json"

if (-not (Test-Path $config_file)) {
    Write-Error "esp32_env.json not found. Run esp32_env_scan.ps1 first."
    exit 1
}

$config = Get-Content $config_file | ConvertFrom-Json
$env:IDF_PATH = $config.idf_path
$env:IDF_TOOLS_PATH = $config.idf_tools_path

# Clear MSYSTEM env vars (inherited from Git Bash, blocks ESP-IDF)
[Environment]::SetEnvironmentVariable("MSYSTEM", $null, 'Process')
[Environment]::SetEnvironmentVariable("MSYS2_PATH", $null, 'Process')
[Environment]::SetEnvironmentVariable("MINGW_PREFIX", $null, 'Process')
[Environment]::SetEnvironmentVariable("MINGW_CHOST", $null, 'Process')

# Clear proxy duplicate vars
Get-ChildItem Env: | Where-Object { $_.Name -like '*proxy*' } | ForEach-Object {
    [Environment]::SetEnvironmentVariable($_.Name, $null, 'Process')
}

# Export ESP-IDF environment
Set-Location $env:IDF_PATH
& .\export.ps1
