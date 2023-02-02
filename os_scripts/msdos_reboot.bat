echo off
cls
set txt=Arran rebooting
echo %txt% > "e:\chemist\rebooting.txt"
date /T >> "e:\chemist\rebooting.txt"
time /t >> "e:\chemist\rebooting.txt"
shutdown /r /t 120 /c NMR_automation_starting /d p:0:0
exit