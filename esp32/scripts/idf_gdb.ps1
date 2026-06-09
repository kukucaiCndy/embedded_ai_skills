# ESP-IDF GDB Test Script for ESP32-S3
# Runs a non-interactive GDB session to verify JTAG connection
param(
    [string]$project_path = "."
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

# Find GDB binary
$gdb_bin_dir = Join-Path $config.idf_tools_path "tools\xtensa-esp-elf-gdb\17.1_20260402\xtensa-esp-elf-gdb\bin"
$gdb_exe = Join-Path $gdb_bin_dir "xtensa-esp32s3-elf-gdb.exe"
$elf_file = Join-Path $project_path "build\esp32_project.elf"

# Add GDB dir to PATH for DLL dependencies
$env:PATH = "$gdb_bin_dir;$env:PATH"

Write-Host "=== GDB Connection Test ==="
Write-Host "GDB: $gdb_exe"
Write-Host "ELF: $elf_file"
Write-Host ""

if (-not (Test-Path $elf_file)) {
    Write-Error "ELF file not found: $elf_file"
    exit 1
}

# Create temp GDB commands file
$tmpfile = Join-Path $env:TEMP "esp32_gdb_cmds.txt"
@"
set pagination off
set remote hardware-breakpoint-limit 2
set remote hardware-watchpoint-limit 2
target remote :3333
mon reset halt
info threads
continue
interrupt
bt
detach
quit
"@ | Out-File -FilePath $tmpfile -Encoding ASCII

# Run GDB in batch mode
& $gdb_exe --batch -x $tmpfile $elf_file

Remove-Item $tmpfile -ErrorAction SilentlyContinue
