<#
.SYNOPSIS
Installs the Windows MOTD system.
Must be run as Administrator.
#>

# Ensure running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "This script must be run as Administrator. Please relaunch in an elevated prompt."
    exit
}

$installDir = "C:\ProgramData\WindowsMOTD"

# 1. Create directory if it doesn't exist
if (-not (Test-Path $installDir)) {
    New-Item -Path $installDir -ItemType Directory -Force | Out-Null
}

# 2. Copy the files
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Copy-Item -Path (Join-Path $scriptDir "motd.md") -Destination $installDir -Force
Copy-Item -Path (Join-Path $scriptDir "show-motd.ps1") -Destination $installDir -Force

# 3. Secure the MOTD markdown file so only Admins can write to it
$motdFilePath = Join-Path $installDir "motd.md"

# Disable inheritance and remove existing rules
$acl = Get-Acl $motdFilePath
$acl.SetAccessRuleProtection($true, $false)

# Grant Administrators full control
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators", "FullControl", "Allow")
$acl.AddAccessRule($adminRule)

# Grant SYSTEM full control
$systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
$acl.AddAccessRule($systemRule)

# Grant Users Read and Execute
$usersRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", "ReadAndExecute", "Allow")
$acl.AddAccessRule($usersRule)

Set-Acl -Path $motdFilePath -AclObject $acl

Write-Host "Permissions on motd.md configured successfully."

# 4. Create the Scheduled Task
$taskName = "WindowsMOTD"
$taskScriptPath = Join-Path $installDir "show-motd.ps1"

# Remove the task if it already exists to recreate it cleanly
Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

# Create trigger: At Logon, for any user
$trigger = New-ScheduledTaskTrigger -AtLogon

# Create action: Run PowerShell hidden and execute the script
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$taskScriptPath`""

# Create principal to run as the logged-on user
$principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Limited

# Register the task
Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Principal $principal -Description "Displays the Message of the Day on user logon." -Force | Out-Null

Write-Host "MOTD Installation complete! Scheduled task '$taskName' created."
