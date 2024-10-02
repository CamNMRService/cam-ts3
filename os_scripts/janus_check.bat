echo off
cls
set file="e:\chemist\janus_running.txt"
set txt="Janus is running."
del %file%

wmic process get Description | findstr /I "Janus_sx"
if %errorlevel% == 0 (
    echo %txt% > %file%
    wmic  process get ProcessId,Description,ParentProcessId,ReadOperationCount,WriteOperationCount /format:csv | findstr /I "Janus_sx" > %file%
) else (
    echo Not running Janus
)