set file="e:\chemist\janus_running.txt"
set txt="Janus is running."
wmic process get Description | findstr /I "Janus"
if %errorlevel% == 0 (
    echo %txt% > %file%
    wmic process get ProcessId,Description,ParentProcessId,ReadOperationCount,WriteOperationCount | findstr /I "Janus" > %file%
) else (
    echo Not running Janus
)