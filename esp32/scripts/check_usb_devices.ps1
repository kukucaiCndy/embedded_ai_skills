# Check USB and JTAG devices
Write-Host "=== USB Controllers ==="
Get-PnpDevice -Class USB | Where-Object { $_.FriendlyName -match 'JTAG|Serial|COM' -or $_.Status -eq 'OK' } | Select-Object -First 10 | Format-Table FriendlyName, Status -AutoSize

Write-Host "=== COM Ports ==="
Get-PnpDevice -Class Ports | Format-Table FriendlyName, Status -AutoSize

Write-Host "=== All ESP-related ==="
Get-PnpDevice | Where-Object { $_.FriendlyName -match 'esp|jtag|serial' } | Format-Table FriendlyName, Status, Class -AutoSize
