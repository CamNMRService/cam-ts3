echo off
cls
wmic process get Description | findstr /I "Janus"
if %errorlevel% == 0 (
	echo Running Janus-no need to reboot
	exit
) else (

start msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 4 more warnings."
start msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 3 more warnings."
start msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 2 more warnings."
start msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 1 more warning."
start msg * /time:60 "SYSTEM REBOOT - LAST WARNING. Please halt your experiments!!"
TIMEOUT /T 300 /nobreak
set txt=Arran rebooting
echo %txt% > "e:\chemist\rebooting.txt"
date /T >> "e:\chemist\rebooting.txt"
time /t >> "e:\chemist\rebooting.txt"
shutdown /r /t 120 /c NMR_automation_starting /d p:0:0
exit
)