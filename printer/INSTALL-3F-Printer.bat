@echo off
title 3F Printer Helper - Install
echo.
echo  Installing the 3F Printer Helper on this POS computer...
echo  (prints receipts directly, cuts the paper and opens the cash drawer)
echo.
set "D=%LOCALAPPDATA%\3FPrinter"
if not exist "%D%" mkdir "%D%"
copy /Y "%~dp03F-Printer-Helper.ps1" "%D%\3F-Printer-Helper.ps1" >nul
if errorlevel 1 (
  echo  ERROR: put this file in the SAME folder as 3F-Printer-Helper.ps1, then run it again.
  pause
  exit /b 1
)
> "%D%\start.vbs" echo CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""%D%\3F-Printer-Helper.ps1""", 0, False
copy /Y "%D%\start.vbs" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\3F Printer Helper.vbs" >nul
wscript.exe "%D%\start.vbs"
echo  DONE. The helper is running now and starts by itself every time Windows starts.
echo.
echo  Next: open the 3FMS POS, go to  Receipt printer settings  and choose
echo        Printing:  Direct  and your receipt printer, then press  Test print.
echo.
pause
