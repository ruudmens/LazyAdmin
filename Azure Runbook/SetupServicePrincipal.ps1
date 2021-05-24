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

# Connect to Azure AD
Connect-AzureAD

# Set the Service Principal object id
$servicePrincipalObjectId = "6dbd7716-0e4a-47fb-b470-de3a91f39adc"

# Optional - list ActiveDirectory Roles
# Get-AzureADDirectoryRole

# Grant the service principal Global Admin permission.
# If you only need read access, then make it member of the Directory Readers role.
Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole | where-object {$_.DisplayName -eq "Company Administrator"}).Objectid -RefObjectId $servicePrincipalObjectId

# Assign Exchange Online Permission
Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole | where-object {$_.DisplayName -eq "Exchange Administrator"}).Objectid -RefObjectId $servicePrincipalObjectId

# Get the Service Principal object
$servicePrincipal = Get-AzureADServicePrincipal -ObjectId $servicePrincipalObjectId

#
# Get the Office 365 Exchange Online App
#
$EXOApp = (Get-AzureADServicePrincipal -Filter "AppID eq '00000002-0000-0ff1-ce00-000000000000'")

# Get the roles
$permission = $EXOApp.AppRoles | Where-Object { $_.Value -eq 'Exchange.ManageAsApp' }

$apiPermission = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
    ResourceAppId  = $EXOApp.AppId ;
    ResourceAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
        Id   = $permission.Id ;
        Type = "Role"
    }
}

$Application = Get-AzureADApplication | Where-Object {$_.AppId -eq $servicePrincipal.AppId}
$Application | Set-AzureADApplication -ReplyUrls 'http://localhost'
$Application | Set-AzureADApplication -RequiredResourceAccess $apiPermission

#
# Get Office 365 SharePoint Online App
#
$spApp = (Get-AzureADServicePrincipal -Filter "AppID eq '00000003-0000-0ff1-ce00-000000000000'")

# Get the roles
# All sites full control
$spSitesControl = $SPApp.AppRoles | Where-Object { $_.Value -eq 'Sites.FullControl.All' }

# User read write
$spUserControl= $SPApp.AppRoles | Where-Object { $_.Value -eq 'User.ReadWrite.All' }

# TermStore
$spTermControl= $SPApp.AppRoles | Where-Object { $_.Value -eq 'TermStore.ReadWrite.All' }

# NOTE: If you format the code below nicely, and copy-paste it, it will make typeID from the Id attribute :s

$spPermission = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
    ResourceAppId  = $spApp.AppId ;
    ResourceAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id   = $spSitesControl.Id;Type = "Role";},
				[Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id   = $spUserControl.Id;Type = "Role";},
				[Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id   = $spTermControl.Id ;Type = "Role";}
}

$Application = Get-AzureADApplication | Where-Object {$_.AppId -eq $servicePrincipal.AppId}
$Application | Set-AzureADApplication -ReplyUrls 'http://localhost'
$Application | Set-AzureADApplication -RequiredResourceAccess $spPermission

#
# Get Graph App
#
$graphApp = (Get-AzureADServicePrincipal -Filter "AppID eq '00000003-0000-0000-c000-000000000000'")

# Group read write
$graphGroupControl = $graphApp.AppRoles | Where-Object { $_.Value -eq 'Group.ReadWrite.All' }

# User read write
$graphUserControl = $graphApp.AppRoles | Where-Object { $_.Value -eq 'User.ReadWrite.All' }

# NOTE: If you format the code below nicely, and copy-paste it, it will make typeID from the Id attribute :s
$graphPermission = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
    ResourceAppId  = $graphApp.AppId ;
    ResourceAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id   = $graphGroupControl.Id;Type = "Role";},
				[Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id   = $graphUserControl.Id;Type = "Role";}
}

$Application = Get-AzureADApplication | Where-Object {$_.AppId -eq $servicePrincipal.AppId}
$Application | Set-AzureADApplication -ReplyUrls 'http://localhost'
$Application | Set-AzureADApplication -RequiredResourceAccess $graphPermission

