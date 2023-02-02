echo off
cls
msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 4 more warnings."
msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 3 more warnings."
msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 2 more warnings."
msg * /time:60 "System will reboot shortly. Please halt your experiments. There will be 1 more warning."
msg * /time:60 "SYSTEM REBOOT - LAST WARNING. Please halt your experiments!!"
set txt=Arran rebooting
echo %txt% > "e:\chemist\rebooting.txt"
date /T >> "e:\chemist\rebooting.txt"
time /t >> "e:\chemist\rebooting.txt"
shutdown /r /t 120 /c NMR_automation_starting /d p:0:0
exit