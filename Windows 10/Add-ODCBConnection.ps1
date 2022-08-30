<#
.SYNOPSIS
  Add a new ODBC Connection to Windows
.DESCRIPTION
  Check if ODBC connection exists, if not, add the connection

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  11 mrt 2022
  Purpose/Change: Init
#>

$connection = @{
    "Name" = "Connection name";
    "DriverName" = "SQL Server";   
    "DsnType" = "User";
    "Platform" = "64-bit";
    "SetPropertyValue" = ("Description=Test connection", "Server=la-db\dev", "Trusted_Connection=Yes", "Database=la-test");
}
    
Try {
    Get-OdbcDsn -Name $connection.Name -ErrorAction Stop
}Catch{ 
    Write-Host "DNS doesn't exist, adding it"
    Add-OdbcDsn @connection
}