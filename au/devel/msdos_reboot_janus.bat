SET file="y:\chemist\rebooting.txt"
SET spect="arran"
IF EXIST %file% (
  ECHO %file% is existing
  shutdown /r /t 5 /c %spect%_automation_starting /d p:0:0
) 