echo off
cls
start c:\windows\system32\msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 4 more warnings."
start c:\windows\system32\msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 3 more warnings."
start c:\windows\system32\msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 2 more warnings."
start c:\windows\system32\msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 1 more warning."
start c:\windows\system32\msg.exe * /time:60 "SYSTEM REBOOT - LAST WARNING. Please halt your experiments!!"
TIMEOUT /T 300 /nobreak
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