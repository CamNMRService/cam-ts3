cd c:\nmrkiosk\
start /b nmrkiosk.exe
REM now start infinite loop
:l
TIMEOUT /T 60
cd c:\msdos_scripts\
c:\msdos_scripts\msdos_reboot_janus.bat
goto l
