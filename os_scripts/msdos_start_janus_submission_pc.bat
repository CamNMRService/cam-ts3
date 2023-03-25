REM This file needs to go into the startup of Windows on the submission PC

REM Check wether file made by spectrometer is here. If we remove this, we know this PC has rebooted
SET file="y:\janus_rebooting.txt"
SET spect=arran
IF EXIST %file% (
  ECHO %file% is existing
  DEL %file%
) 

REM above so we don't reboot loop.
REM If the janus pc loses connection, we can trigger msdos_reboot on arran

SET file="y:\spect_rebooting.txt"

cd c:\nmrkiosk\
start /b nmrkiosk.exe
REM now start infinite loop
:l
TIMEOUT /T 60 /nobreak
cd c:\msdos_scripts\
REM c:\msdos_scripts\msdos_reboot_janus.bat
IF EXIST %file% (
  ECHO %file% is existing
  shutdown /r /t 300 /c %spect%_automation_starting /d p:0:0
) 
goto l

