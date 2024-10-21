
echo off
cls

TIMEOUT /T 100 /nobreak
set txt=Arran rebooting
SET file="e:\chemist\spect_rebooting.txt"
echo %txt% > %file%
date /T >> %file%
time /t >> %file%
set %txt%=Reboot janus
SET file="e:\chemist\janus_rebooting.txt"
echo %txt% > %file%
shutdown /r /t 120 /c NMR_automation_starting /d p:0:0
exit