SET file="y:\rebooting.txt"
SET spect="arran"
IF EXIST %file% (
  ECHO %file% is existing
  shutdown /r /t 120 /c %spect%_automation_starting /d p:0:0
) 