<#
.SYNOPSIS
	Gives your Azure Run As Account the correct permissions to access Office 365 APIs

.DESCRIPTION
	With the correct API permissions added to your Run As account, you are able to access
	all the Office 365 APIs and Microsoft Graph from your Azure Automation Runbooks

.NOTES
	Version:        1.1
	Author:         R. Mens
	Blog:						http://lazyadmin.nl
	Creation Date:  24-05-2021

.Change
	1.2 Use filter instead of where-object
	1.1 Set all permissions in one run so you only have to grant admin consent once.
	
.LINK
	https://lazyadmin.nl/powershell/azure-automation-authentication-and-runbooks/
#>

# Connect to Azure AD
Connect-AzureAD

# Set the Service Principal object id
# Lookup the object id of your run as account in Azure > Automation > Azure Run As Account
$servicePrincipalObjectId = ""

# Grant the service principal Global Admin permission.
# If you only need read access, then make it member of the Directory Readers role.
# 
# If you get the error "Cannot bind argument to parameter 'ObjectId' because it is null" then check the AzureAD Directory Roles for the correct DisplayNames
# Global Administrator is in some tenants Company Administrator

# Optional - list ActiveDirectory Roles
# Get-AzureADDirectoryRole

Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole -Filter "Displayname eq 'Global Administrator'").ObjectId -RefObjectId $servicePrincipalObjectId

# Assign Exchange Online Permission
# First check if we have the Exchange Administrator role in our tenant, otherwise enable it.
if (Get-AzureADDirectoryRole | where-object {$_.DisplayName -eq "Exchange Administrator"} -eq $null) { 
	Enable-AzureADDirectoryRole -RoleTemplateId (Get-AzureADDirectoryRole -Filter "Displayname eq 'Exchange Administrator'").ObjectId
}
Add-AzureADDirectoryRoleMember -ObjectId (Get-AzureADDirectoryRole -Filter "Displayname eq 'Exchange Administrator'").ObjectId -RefObjectId $servicePrincipalObjectId

# Get the Service Principal object
$servicePrincipal = Get-AzureADServicePrincipal -ObjectId $servicePrincipalObjectId

#
# Get the Office 365 Exchange Online App
#
$EXOApp = (Get-AzureADServicePrincipal -Filter "AppID eq '00000002-0000-0ff1-ce00-000000000000'")

# Get the roles
$EXOPermission = $EXOApp.AppRoles | Where-Object { $_.Value -eq 'Exchange.ManageAsApp' }

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

#
# Get Graph App
#
$graphApp = (Get-AzureADServicePrincipal -Filter "AppID eq '00000003-0000-0000-c000-000000000000'")

# Group read write
$graphGroupControl = $graphApp.AppRoles | Where-Object { $_.Value -eq 'Group.ReadWrite.All' }

# User read write
$graphUserControl = $graphApp.AppRoles | Where-Object { $_.Value -eq 'User.ReadWrite.All' }

#
# Set API permission on the Run As account
#
# NOTE: If you format the code below nicely, and copy-paste it, it will make typeID from the Id attribute or add mess up the ResourceAccess lines. :s
$apiPermission = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
											ResourceAppId  = $EXOApp.AppId ;
											ResourceAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id = $EXOPermission.Id;Type = "Role"}
									},
									[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
											ResourceAppId  = $spApp.AppId ;
											ResourceAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id = $spSitesControl.Id;Type = "Role";},
													[Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id = $spUserControl.Id;Type = "Role";},
													[Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id = $spTermControl.Id ;Type = "Role";}
									},
									[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
											ResourceAppId  = $graphApp.AppId ;
											ResourceAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id = $graphGroupControl.Id;Type = "Role";},
													[Microsoft.Open.AzureAD.Model.ResourceAccess]@{Id = $graphUserControl.Id;Type = "Role";}
									}

$Application = Get-AzureADApplication | Where-Object {$_.AppId -eq $servicePrincipal.AppId}
$Application | Set-AzureADApplication -ReplyUrls 'http://localhost'
$Application | Set-AzureADApplication -RequiredResourceAccess $apiPermission