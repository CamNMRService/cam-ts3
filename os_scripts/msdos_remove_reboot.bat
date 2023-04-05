
SET file=Y:\rebooting.txt
SET spect="arran"
IF EXIST %file% (
  ECHO %file% is existing
  DEL %file%
) 