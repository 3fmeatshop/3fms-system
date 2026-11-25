@echo off
title 3F Printer Helper - Remove
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -Filter \"Name='powershell.exe'\" | Where-Object { $_.CommandLine -like '*3F-Printer-Helper*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
del /Q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\3F Printer Helper.vbs" 2>nul
rmdir /S /Q "%LOCALAPPDATA%\3FPrinter" 2>nul
echo  The 3F Printer Helper is removed. Receipts will use the normal print window again.
pause
