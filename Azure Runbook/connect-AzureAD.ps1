<#
.SYNOPSIS
	Connect to Office 365 Security and Compliance Center. Optional save credentials for autonomous execution

.DESCRIPTION
	Connect to Security and Compliance Center. You can store your credentials in the script root. When 
	saved the script will connect automaticaly. if no credentials are found it will ask for them.

.EXAMPLE
	Connecting to Security and Compliance Center

	.\ConnectTo-Compliance.ps1

.EXAMPLE
	Save credentials in the script root

	.\ConnectTo-Compliance.ps1 -save
   
.NOTES
	Version:        1.3
	Author:         R. Mens
	Blog:			http://lazyadmin.nl
	Creation Date:  29 mrt 2017
	
.LINK
	https://github.com/ruudmens/SysAdminScripts/tree/master/Connectors
#>


# Get the service principal connection details
$spConnection = Get-AutomationConnection -Name AzureRunAsConnection

$tenantName = "contoso.onmicrosoft.com"

# Connect to ExchangeOnline
Connect-ExchangeOnline -CertificateThumbprint $spConnection.CertificateThumbprint -AppId $spConnection.ApplicationID -Organization $tenantName

# Test connection
(Get-ExoMailbox).count

# Close connection when done
Disconnect-ExchangeOnline

# Connect to SharePoint
Connect-PnPOnline -ClientId $spConnection.ApplicationID -Url "https://contoso.sharepoint.com" -Tenant $tenantName -Thumbprint $spConnection.CertificateThumbprint


# User Graph
$accessToken = Get-PnPAccessToken

$header = @{
  "Content-Type" = "application/json"
  Authorization = "Bearer $accessToken"
}

# Get users to test Graph
Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/" -Method Get -Headers $header

# Close Connection
Disconnect-PnPOnline


# Connect to AzureAD
Connect-AzureAD -TenantId $spConnection.TenantId -ApplicationId $spConnection.ApplicationID -CertificateThumbprint $spConnection.CertificateThumbprint | Out-null

"User count:" 
(Get-AzureADUser).count

# Close Connection
Disconnect-AzureAD