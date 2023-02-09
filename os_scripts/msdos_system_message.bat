echo off
cls
start msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 4 more warnings."
start msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 3 more warnings."
start msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 2 more warnings."
start msg.exe * /time:60 "System will reboot shortly. Please halt your experiments. There will be 1 more warning."
start msg.exe * /time:60  "SYSTEM REBOOT - LAST WARNING. Please halt your experiments!!"
TIMEOUT /T 300 /nobreak

REM shutdown /r /t 120 /c NMR_automation_starting /d p:0:0
c:\windows\system32\msg.exe "system message test complete!"
exit