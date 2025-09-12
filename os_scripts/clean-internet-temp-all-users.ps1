Param
(
    [string]$ProfileLocation
)

Clear-Host
Write-Host 'Getting User List ...... ' -NoNewline
If ([string]::IsNullOrEmpty($ProfileLocation) -eq $false)
{
    [string]$profilePath = $ProfileLocation
}
Else
{
    [string]$profilePath = (Split-Path -Parent $env:USERPROFILE)
}

[array] $users       = Get-ChildItem -Path   $profilePath
[array] $paths       = (
                        '\AppData\Local\CrashDumps',
                        '\AppData\Local\Temp',
                        '\AppData\Local\Microsoft\Edge\User Data\Default\Cache',
                        '\AppData\Local\Microsoft\Edge\User Data\ProvenanceData',
			'\AppData\Local\Microsoft\Edge\User Data\component_crx_cache',
			'\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache\js',
			'\AppData\Local\Microsoft\Edge\User Data\Default\Service Worker\CacheStorage',
			'\AppData\Local\Google\Chrome\User Data\Default\Code Cache\js',
			'\AppData\Local\Google\Chrome\User Data\Default\Cache\Cache_Data'
                       )
Write-Host ' Complete'
Write-Host 'Scanning User Folders... ' -NoNewline
[double]$before = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($profilePath.SubString(0,2))'" | Select -ExpandProperty FreeSpace

[int]$iCnt      = 0
[int]$UserCount = $users.Count

ForEach ($user In $users)
{
    Write-Progress -Activity 'Scanning User Folders' -Status ($user.Name).ToUpper() -PercentComplete (($iCnt / $UserCount) * 100)
    ForEach ($path In $paths)
    {
        If ((Test-Path -Path "$profilePath\$user\$path") -eq $true)
        {
            Get-ChildItem -Path "$profilePath\$user\$path" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    $iCnt++
}
Write-Host ' Complete'
[double]$after = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$($profilePath.SubString(0,2))'" | Select -ExpandProperty FreeSpace

Write-Output "".PadLeft(80, '-')
Write-Output "Before     : $( ($before           / 1GB).ToString('0.00')) GB"
Write-Output "After      : $( ($after            / 1GB).ToString('0.00')) GB"
Write-Output "Difference : $((($after - $before) / 1MB).ToString('0.00')) MB"
Write-Output "".PadLeft(80, '-')