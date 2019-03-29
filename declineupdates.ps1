[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null
if (-not (Get-WsusServer).GetConfiguration().isreplicaserver) { # don't attempt to decline updates on a replica.
    $sslenabled = (Get-WsusServer).usesecureconnection
    $portnumber = (Get-WsusServer).portnumber
    $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($env:COMPUTERNAME, $sslenabled, $portnumber)
    $updates = $wsus.GetUpdates() | Where-Object {-not $_.IsDeclined -and -not $_.IsApproved}

    # this is slow.  so very, very slow.
    #$updates = Get-WsusUpdate -approval unapproved

    $decline = @() # start with an empty array

    # itanium platform
    foreach ($update in $updates) {
        if ($update.title -like "* Itanium*") {
            $decline += $update
        }
    }

    # arm64 platform
    foreach ($update in $updates) {
        if ($update.title -like "* ARM64-based systems*") {
            $decline += $update
        }
    }

    # 32 bit windows updates
    foreach ($update in $updates) {
        if ($update.title -like "* x86 based systems*") {
            $decline += $update
        }
    }

    # 32 bit malware tool
    foreach ($update in $updates) {
        if ($update.title -like "windows malicious software removal tool -*") {
            $decline += $update
        }
    }

    # previews
    foreach ($update in $updates) {
        if ($update.title -like "*preview of *") {
            $decline += $update
        }
    }

    # security only
    foreach ($update in $updates) {
        if ($update.title -like "*security only *") {
            $decline += $update
        }
    }

    # updates superseded by > 3 months
    $3monthsago = (get-date).AddMonths(-3)
    foreach ($update in $updates) {
        if ($3monthsago -gt $update.creationdate -and $update.IsSuperseded -eq $true) {
            $decline += $update
        }
    }

    # 64 bit versions of office
    foreach ($update in $updates) {
        if ($update.title -like "* 64-bit edition*" -and $update.products -contains "Office 2013") {
            $decline += $update
        } elseif ($update.title -like "* 64-bit edition*" -and $update.products -contains "Office 2016") {
            $decline += $update
        } elseif ($update.title -like "* 64-bit edition*" -and $update.products -contains "Office 365") {
            $decline += $update
        }
    }

    # all updates before the convenience rollups

    # windows 7 and 2008 r2 - updates from feb 2011 and may 16, 2016
    # exclude the servicing stack update from april 2015 - https://support.microsoft.com/help/3020369
    # SP1 is also a prerequisite - https://support.microsoft.com/help/976932
    # https://support.microsoft.com/en-ca/help/3125574/convenience-rollup-update-for-windows-7-sp1-and-windows-server-2008-r2

    # windows 8.1 and server 2012 r2 - updates from before march 2014
    # exclude the servicing stack update from 2014 - https://support.microsoft.com/en-us/help/2919442/march-2014-servicing-stack-update-for-windows-8-1-and-windows-server-2
    # https://support.microsoft.com/en-ca/help/2919355/windows-rt-8-1-windows-8-1-and-windows-server-2012-r2-update-april-201


    # decline the list of updates built above
    write-host $decline.count "updates declined out of " $updates.count
    foreach ($update in $decline) {
        write-host "declining" $update.title
        # Deny-WsusUpdate -update $update
        $update.Decline()
    }
}