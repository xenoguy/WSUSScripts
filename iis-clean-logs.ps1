# iis log cleanup
$maxDaystoKeep = -30 
Import-Module WebAdministration

foreach($WebSite in $(get-website)) {
    $logfolder="$($Website.logFile.directory)\w3svc$($website.id)".replace("%SystemDrive%",$env:SystemDrive)

    $itemsToDelete = Get-ChildItem $logfolder -Recurse -File *.log | Where-Object LastWriteTime -lt ((get-date).AddDays($maxDaystoKeep)) 
    if ($itemsToDelete.Count -gt 0) { 
        ForEach ($item in $itemsToDelete) { 
            Get-item $logfolder\$item | Remove-Item -Verbose 
        } 
    } 
} 

