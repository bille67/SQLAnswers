$tot_mem=(Get-WmiObject -Class Win32_ComputerSystem -computer .).TotalPhysicalMemory


$sql_mem=$tot_mem*.75
"sql mem is $sql_mem"
$sql_mem_mb=$sql_mem/(1024*1024)
"sql mem_mb is $sql_mem"

invoke-sqlcmd "Exec sp_configure 'show advanced options' ,1" -ServerInstance .
invoke-sqlcmd "reconfigure with override" -ServerInstance .

invoke-sqlcmd "EXEC sp_configure 'max server memory (MB)', $sql_mem_mb" -ServerInstance .
invoke-sqlcmd "reconfigure with override" -ServerInstance .
