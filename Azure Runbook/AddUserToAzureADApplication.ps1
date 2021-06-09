<#
  .Synopsis
    Azure Runbook - AddUserToAttlasian

  .DESCRIPTION
    Add the user to the enterprise application atlassian cloud for Jira. This way user can be add in the helpdesk tool

  .NOTES
    Name: RunBook - AddUserToAttlasian 
    Author: R. Mens  - LazyAdmin.nl
    Version: 1.1
    DateCreated: April 2021
    Purpose/Change: used only AzureAd
                    Compare licensed users and atlassian user, add the missing

  .LINK
    https://lazyadmin.nl
#>

# Get the service principal connection details
$spConnection = Get-AutomationConnection -Name AzureRunAsConnection

# Connect AzureAD
# Check if Azure is installed and connect
if ((Get-Module -ListAvailable -Name AzureAd) -ne $null) 
{
    Connect-AzureAD -TenantId $spConnection.TenantId -ApplicationId $spConnection.ApplicationID -CertificateThumbprint $spConnection.CertificateThumbprint | Out-null
}else{
	Write-Error "Please install AzureAd."
}

# Get the service principal for the app you want to assign the user to
$servicePrincipal = Get-AzureADServicePrincipal -Filter "Displayname eq 'APPLICATION NAME'"

# Get all users that are already assigned to Atlassian Cloud
$existingUsers = Get-AzureADServiceAppRoleAssignment -all $true -ObjectId $servicePrincipal.Objectid | select -ExpandProperty PrincipalId

# Get all licensedUsers
$licensedUsers = Get-AzureADUser -all $true | Where-Object {$_.AssignedLicenses} | Select displayname,objectid

# Compare lists
$newUsers = $licensedUsers | Where-Object { $_.ObjectId -notin $existingUsers }

ForEach ($user in $newUsers) {
  Try {
    New-AzureADUserAppRoleAssignment -ObjectId $user.ObjectId -PrincipalId $user.ObjectId -ResourceId $servicePrincipal.ObjectId -Id $servicePrincipal.Approles[0].id -ErrorAction Stop

    [PSCustomObject]@{
        UserPrincipalName = $user.displayname
        AppliciationAssigned = $true
    }
  }
  catch {
    [PSCustomObject]@{
        UserPrincipalName = $user.displayname
        AppliciationAssigned = $false
    }
  }
}

# Close Connection
Disconnect-AzureAD