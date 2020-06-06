start "Simulator" simulator.exe
Start-Sleep -Seconds 1
write-host $args[0] $args[1]
& monkeydo.bat $Args[0] $Args[1]