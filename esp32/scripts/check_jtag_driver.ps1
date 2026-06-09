# Full USB device scan for ESP32-S3
Write-Host "=== All USB devices with VID 303A or ESP-related ==="
Get-PnpDevice | Where-Object { $_.InstanceId -match 'VID_303A|VID_0403' } | ForEach-Object {
    Write-Host "--------------------------------------------------"
    Write-Host "FriendlyName : $($_.FriendlyName)"
    Write-Host "Status       : $($_.Status)"
    Write-Host "InstanceId   : $($_.InstanceId)"
    
    $desc = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_BusReportedDeviceDesc' 2>$null
    $svc  = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_Service' 2>$null
    $hwid = Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' 2>$null
    
    if ($desc) { Write-Host "Description  : $($desc.Data)" }
    if ($svc)  { Write-Host "Service      : $($svc.Data)" }
    if ($hwid) { 
        Write-Host "Hardware IDs :"
        $hwid.Data | ForEach-Object { Write-Host "  $_" }
    }
    Write-Host ""
}

Write-Host "=== Current COM ports ==="
[System.IO.Ports.SerialPort]::GetPortNames() | ForEach-Object { Write-Host "  $_" }
