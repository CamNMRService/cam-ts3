SET file="y:\rebooting.txt"
SET spect=arran
IF EXIST %file% (
  ECHO %file% is existing
  DEL %file%
) 
REM above so we don't reboot loop.
REM If the janus pc loses connection, we can trigger msdos_reboot on arran

cd c:\nmrkiosk\
start /b nmrkiosk.exe
REM now start infinite loop
:l
TIMEOUT /T 60 /nobreak
cd c:\msdos_scripts\
REM c:\msdos_scripts\msdos_reboot_janus.bat
IF EXIST %file% (
  ECHO %file% is existing
  shutdown /r /t 180 /c %spect%_automation_starting /d p:0:0
) 
goto l

