SET file="y:\rebooting.txt"
cd c:\nmrkiosk\
start /b nmrkiosk.exe
REM now start infinite loop
:l
TIMEOUT /T 60 /nobreak
cd c:\msdos_scripts\
REM c:\msdos_scripts\msdos_reboot_janus.bat
IF EXIST %file% (
  ECHO %file% is existing
  shutdown /r /t 5 /c %spect%_automation_starting /d p:0:0
) 
goto l

