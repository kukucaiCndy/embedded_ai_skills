# ESP-IDF: Set target + Build
param(
    [string]$project_path = ".",
    [string]$target = "esp32s3"
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

Set-Location $project_path

Write-Host "=== Setting target: $target ==="
idf.py set-target $target
if ($LASTEXITCODE -ne 0) {
    Write-Error "set-target failed."
    exit 1
}

Write-Host "=== Building ==="
idf.py build
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed."
    exit 1
}

Write-Host "=== Build successful! ==="
