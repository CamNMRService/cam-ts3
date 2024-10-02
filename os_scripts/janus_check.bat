
echo off
cls
set file="e:\chemist\janus_running.txt"
set txt="Janus is running."
wmic process get Description | findstr /I "Janus_sx"
if %errorlevel% == 0 (
    echo %txt% > %file%
    wmic /format:csv process get ProcessId,Description,ParentProcessId,ReadOperationCount,WriteOperationCount | findstr /I "Janus_sx" > %file%
) else (
    echo Not running Janus
)