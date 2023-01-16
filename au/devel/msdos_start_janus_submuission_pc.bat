cd c:\nmrkiosk\
nmrkiosk.exe
REM now start infinite loop
:l
TIMEOUT /T 60
c:\msdos_scripts\msdos_reboot_janus.bat
goto l
