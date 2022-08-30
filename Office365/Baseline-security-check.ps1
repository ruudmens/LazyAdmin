<#
.SYNOPSIS
  Check baseline security setting in Office 365

.DESCRIPTION
 This script will check you security settings in Office 365. It won't change anything (yet)

.OUTPUTS
  

.NOTES
  Version:        0.1
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  03 march 2021
  Purpose/Change: Initial script development
#>

$adminUPN = Read-Host 'Please enter your userprincipalname to connect to Exchange Online';

# Check if EXO is installed and connect if no connection exists
if ((Get-Module -ListAvailable -Name ExchangeOnlineManagement) -ne $null) 
{
	# Check if there is a active EXO sessions
	$psSessions = Get-PSSession | Select-Object -Property State, Name
	If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
		Connect-ExchangeOnline -UserPrincipalName $adminUPN
	}
}
else{
	Write-Error "Please install EXO v2 module."
}

#region 1 -  Check Unified Audit Log settings
$UnifiedLogging = Get-AdminAuditLogConfig | select UnifiedAuditLogIngestionEnabled -ExpandProperty UnifiedAuditLogIngestionEnabled
[PSCustomObject]@{
	Label = "Unified logging enabled"
	Status = $UnifiedLogging
}
#endregion 