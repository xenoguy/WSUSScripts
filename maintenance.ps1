param (
    [switch]$wid, # -wid - windows internal database.  if not specified, defaults to local SQL install
    [switch]$replica # -replica - indicates the script is being run on a replica of an upstream WSUS server, doesn't decline updates.
)

cd $PSScriptRoot

# include the PS function to run sql commands
# you can also run the individual sql commands with sql server management studio, or the sql command line tools (sqlcmd).
function execute-sqlcmd ($sqlquery) {
    $SQLDBName = "SUSDB"
    $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $SqlConnection.ConnectionString = "Server = $SQLServer; Database = $SQLDBName; Integrated Security = True"

    if ($sqlquery -like "*GO*") { 
        $sqlqueries = $sqlquery -split "\nGO"
    } else {
        $sqlqueries = @($sqlquery)
    }

    foreach ($query in $sqlqueries) {
        if ($query -ne "") {
            $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
            $SqlCmd.Connection = $SqlConnection
            $SqlCmd.CommandText = $query
            $SqlCmd.CommandTimeout = 9000
            $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
            $SqlAdapter.SelectCommand = $SqlCmd
            $DataSet = New-Object System.Data.DataSet
            $OutPut = $SqlAdapter.Fill($DataSet)
            if ($OutPut -ne 0) {
                # Write-Host "$OutPut rows returned"
            }
        }
    }
    #Close SQL connection
    $SqlConnection.Close()
    if ($DataSet.Tables) {
        return $DataSet.Tables
    }
}

if ($wid) {
    # windows internal database using named pipes
    $SQLServer = "np:\\.\pipe\MICROSOFT##WID\tsql\query"
} else {
    # local SQL server
    $SQLServer = $env:COMPUTERNAME
}

# try to detect if you're using WID or SQL automatically.
$sqltext = "select name from sys.databases WHERE name='SUSDB'"
$result = execute-sqlcmd $sqltext
if (-not $result.rows.count) {
    # assume WID if there's no SUSDB via SQL connection
    $SQLServer = "np:\\.\pipe\MICROSOFT##WID\tsql\query"
}

# adjusts the IIS app pool memory for WSUS.  often if there are a lot of updates, this needs more memory.  otherwise it tends to crash.
# technically you only need to run this once.
write-host "Adusting wsus app pool and restarting IIS"
.\wsus-fix-iis-apppool.ps1

# these indexes are unsupported, but they should speed things up significantly.
# there are definitely more indexes that could be added.
# technically you only need to run this once.
write-host "adding indexes to SQL db"
$sqltext = get-content "wsus-add-indexes.sql" -raw
execute-sqlcmd $sqltext

# this comes from https://gallery.technet.microsoft.com/scriptcenter/6f8cde49-5c52-4abd-9820-f1d270ddea61
write-host "rebuilding fragmented indexes"
$sqltext = get-content "wsus-index-rebuild.sql" -raw
execute-sqlcmd $sqltext

# clear the sync history.  the sync history is never truncated and can take an extremely long time to load in the console
# this script removes the history
write-host "clearing sync history"
$sqltext = get-content "wsus-clear-synchistory.sql" -raw
execute-sqlcmd $sqltext

# this often times out using the powershell cmdlets, using the sql stored procedures directly doesn't timeout.
#write-host "cleaning obselete updates, this can take a very long time"
#$sqlcmd = get-content "wsus-clean-updates.sql"
#execute-sqlcmd $sqlcmd
write-host "getting a list of obselete updates"
$sqltext = get-content "wsus-get-obseleteupdates.sql" -raw
$obsupdates = execute-sqlcmd $sqltext
write-host $obsupdates.rows.count "updates to clean up"

# execute individual update deletions with progress bar instead of in one unresponsive batch SQL command.
$step = 1
$totalsteps = $obsupdates.rows.count
$Activity = "Removing obselete updates"
$Id       = 1
$StatusText = '"Update $($Step.ToString().PadLeft($TotalSteps.Count.ToString().Length)) of $TotalSteps"'
$StatusBlock = [ScriptBlock]::Create($StatusText)
foreach ($update in $obsupdates.rows) {
    Write-Progress -Id $Id -Activity $Activity -Status $StatusBlock -PercentComplete ($Step / $TotalSteps * 100)
    execute-sqlcmd ('susdb.dbo.spDeleteUpdate @localUpdateID='+$update.localUpdateID)
    $step++
}

if (-not $replica) { 
    # my downstream WSUS servers are replicas, so they just get the declines from the upstream server
    # if your configuration is different, adjust as necessary.
    .\declineupdates.ps1
}

# run these individually.  They sometimes timeout, causing the other functions to fail if you do them all at once.
Invoke-WsusServerCleanup -CleanupObsoleteComputers
Invoke-WsusServerCleanup -CleanupUnneededContentFiles
Invoke-WsusServerCleanup -CleanupObsoleteUpdates
Invoke-WsusServerCleanup -CompressUpdates
if (-not $replica) {
    Invoke-WsusServerCleanup -DeclineExpiredUpdates
    Invoke-WsusServerCleanup -DeclineSupersededUpdates
}

# this comes from https://gallery.technet.microsoft.com/scriptcenter/6f8cde49-5c52-4abd-9820-f1d270ddea61
write-host "rebuilding fragmented indexes after cleanup is complete"
$sqltext = get-content "wsus-index-rebuild.sql" -raw
execute-sqlcmd $sqltext

# removes IIS logs older than 30 days.
.\iis-clean-logs.ps1

# SCCM content library cleanup tool from microsoft.  works on all DPs that are not management points.
# if you copy it to the script folder, it will run the cleanup for you
if (test-path contentlibrarycleanup.exe) {
    .\contentlibrarycleanup.exe /dp $env:COMPUTERNAME /log $env:temp\cleanup.log /delete /q
}
