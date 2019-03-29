# adjust wsus app pool in IIS
Import-Module WebAdministration
if ((get-ItemProperty -Path IIS:\AppPools\wsuspool -Name queueLength).value -lt 4000) {
    Set-ItemProperty -Path IIS:\AppPools\wsuspool -Name queueLength -Value 4000
    $changed = $true
}
if ((get-ItemProperty -Path IIS:\AppPools\wsuspool -Name "recycling.periodicrestart.memory").value -ne 0) {
    Set-ItemProperty -Path IIS:\AppPools\wsuspool -Name "recycling.periodicrestart.memory" -Value 0
    $changed = $true
}
if ((get-ItemProperty -Path IIS:\AppPools\wsuspool -Name "recycling.periodicrestart.privateMemory").value -ne 0) {
    Set-ItemProperty -Path IIS:\AppPools\wsuspool -Name "recycling.periodicrestart.privateMemory" -Value 0
    $changed = $true
}
# restart IIS
if ($changed) {
    iisreset
}
