Import-Module SQLPS -DisableNameChecking

function add_db_to_ag( $AGName, $PrimaryInstance, $ReplicaInstance, $DBName, $DiskShare, $TlogBackupJob, $CommandTimeout, $LocalPath)
{
    $DatabaseBackupFile = "$DiskShare\$DBName.bak"
    $LogBackupFile = "$DiskShare\$DBName.trn"
    $LocalDatabaseBackupFile = "$LocalPath\$DBName.bak"
    $LocalLogBackupFile = "$LocalPath\$DBName.trn"
    $MyAgPrimaryPath = "SQLSERVER:\SQL\$PrimaryInstance\Default\AvailabilityGroups\$AGName"
    $MyAgSecondaryPath = "SQLSERVER:\SQL\$ReplicaInstance\Default\AvailabilityGroups\$AGName"

    ###### DISABLE TLOG BACKUP
    invoke-sqlcmd "EXEC msdb.dbo.sp_update_job @job_name='$TlogBackupJob', @enabled = 0" -ServerInstance $PrimaryInstance
   
    invoke-sqlcmd "BACKUP DATABASE $DBName TO DISK = N'$DatabaseBackupFile' WITH INIT" -ServerInstance $PrimaryInstance -querytimeout $CommandTimeout
    invoke-sqlcmd "BACKUP Log $DBName TO DISK = N'$LogBackupFile' WITH INIT" -ServerInstance $PrimaryInstance -querytimeout $CommandTimeout

    invoke-sqlcmd "RESTORE DATABASE $DBName FROM DISK = N'$DatabaseBackupFile' WITH NORECOVERY, REPLACE" -ServerInstance $ReplicaInstance -querytimeout $CommandTimeout
    invoke-sqlcmd "RESTORE LOG $DBName FROM DISK = N'$LogBackupFile' WITH NORECOVERY, REPLACE" -ServerInstance $ReplicaInstance -querytimeout $CommandTimeout

    # Re-enable the TLog backups
    invoke-sqlcmd "EXEC msdb.dbo.sp_update_job @job_name='$TlogBackupJob', @enabled = 1" -ServerInstance $PrimaryInstance
    
    invoke-sqlcmd "ALTER AVAILABILITY GROUP [$AGName] ADD DATABASE $DBName" -ServerInstance $PrimaryInstance
    invoke-sqlcmd "ALTER DATABASE $DBName SET HADR AVAILABILITY GROUP = [$AGName]" -ServerInstance $ReplicaInstance

    Remove-Item -force "filesystem::$DatabaseBackupFile"
    Remove-Item -force  "filesystem::$LogBackupFile"
}

function remove_db_from_ag( $AGName, $PrimaryInstance, $ReplicaInstance, $DBName, $CommandTimeout )
{
    #Remove the database from the Availability Group
	try {
		invoke-sqlcmd "alter availability group [$AGName] remove database $DBName" -ServerInstance $PrimaryInstance
	} catch {
		"Error removing $DBName from [$AGName]"
	}

	try {
		invoke-sqlcmd "Alter database $DBName SET single_user with rollback immediate" -ServerInstance $ReplicaInstance -querytimeout $CommandTimeout
    } catch { 
		"Error trying to put $DBName in single user mode"
	}

	try {
		invoke-sqlcmd "Drop database $DBName" -ServerInstance $ReplicaInstance -querytimeout $CommandTimeout
	} catch {
		"Error trying to drop $DBNamein on $ReplicaInstance"
	}
}

##### SETUP VARIABLES
$PrimaryInstance = "PRIMARY_SERVER"
$ReplicaInstance  = "SECONDARY_SERVER"

$AGName = "USE2-WSQL-D-AG"
$CommandTimeout = 43200
$DiskShare = "\\PRIMARY_SERVER\Backups\AG"
$LocalPath = "\\PRIMARY_SERVER\Backups\AG"
$TlogBackupJob="OLA  - DatabaseBackup - USER_DATABASES - LOG"

################ MAIN #######################
remove_db_from_ag $AGName $PrimaryInstance $ReplicaInstance "TestAG_Database" $CommandTimeout

add_db_to_ag $AGName $PrimaryInstance $ReplicaInstance "TestAG_Database" $DiskShare $TlogBackupJob $CommandTimeout $LocalPath
