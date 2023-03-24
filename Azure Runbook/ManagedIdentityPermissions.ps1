#Requires -Modules Microsoft.Graph

<#
.SYNOPSIS
  Set API permission for managed identities
.DESCRIPTION
  Add permissions to Exchange Online, Microsoft Graph and SharePoint to a managed iditity
.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  23 march 2023
  Purpose/Change: Initial script development
#>

# Change this to your Managed Identity app name:
$managedIdentityName = "LazyAutomationAccount"

# Connect to Microsoft Graph
Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All,RoleManagement.ReadWrite.Directory"
Select-MgProfile Beta

# Get the Managed Identity Object id
# You can find the name or object id in Azure > Automation Account > Identity
# $managedIdentityId = "<id-number-goes-here>"
$managedIdentityId = (Get-MgServicePrincipal -Filter "displayName eq $managedIdentityName").id

#
# Adding Microsoft Graph permissions
#
Write-host "Adding Microsoft Graph Permissions" -ForegroundColor Cyan

$graphApp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0000-c000-000000000000'"

# Add the required Graph scopes
$graphScopes = @(
  'UserAuthenticationMethod.Read.All',
  'Group.ReadWrite.All',
  'Directory.Read.All',
  'User.ReadWrite.All'
)
ForEach($scope in $graphScopes){
  $appRole = $graphApp.AppRoles | Where-Object {$_.Value -eq $scope}

  if ($null -eq $appRole) { Write-Warning "Unable to find App Role for scope $scope"; continue; }

  # Check if permissions isn't already assigned
  $assignedAppRole = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId | Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceDisplayName -eq "Microsoft Graph" }

  if ($null -eq $assignedAppRole) {
    New-MgServicePrincipalAppRoleAssignment -PrincipalId $managedIdentityId -ServicePrincipalId $managedIdentityId -ResourceId $graphApp.Id -AppRoleId $appRole.Id
  }else{
    write-host "Scope $scope already assigned"
  }
}

#
# SharePoint Online Permissions
#
Write-host "Adding SharePoint Online Permissions" -ForegroundColor Cyan

$spoApp = Get-MgServicePrincipal -Filter "AppId eq '00000003-0000-0ff1-ce00-000000000000'"

# Add the required SPO scopes
$spoScopes = @(
  'Sites.FullControl.All',
  'TermStore.ReadWrite.All',
  'User.ReadWrite.All'
)
ForEach($scope in $spoScopes){
  $appRole = $spoApp.AppRoles | Where-Object {$_.Value -eq $scope}

  if ($null -eq $appRole) { Write-Warning "Unable to find App Role for scope $scope"; continue; }

  # Check if permissions isn't already assigned
  $assignedAppRole = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityId | Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceDisplayName -eq "Office 365 SharePoint Online"}

  if ($null -eq $assignedAppRole) {
    New-MgServicePrincipalAppRoleAssignment -PrincipalId $managedIdentityId -ServicePrincipalId $managedIdentityId -ResourceId $spoApp.Id -AppRoleId $appRole.Id
  }else{
    write-host "Scope $scope already assigned"
  }
}


#
# Adding Exchange Online permissions
#
Write-host "Adding Exchange Online Permissions" -ForegroundColor Cyan

$exoApp = Get-MgServicePrincipal -Filter "AppId eq '00000002-0000-0ff1-ce00-000000000000'"
$appRole = $exoApp.AppRoles | Where-Object {$_.DisplayName -eq "Manage Exchange As Application"}

$AppRoleAssignment = @{
  "PrincipalId" = $managedIdentityId
  "ServicePrincipalId" = $managedIdentityId
  "ResourceId" = $exoApp.Id
  "AppRoleId" = $appRole.Id
}
New-MgServicePrincipalAppRoleAssignment @AppRoleAssignment

# Add Exchange Administrator Role
$roleId = (Get-MgRoleManagementDirectoryRoleDefinition -Filter "DisplayName eq 'Exchange Administrator'").id
New-MgRoleManagementDirectoryRoleAssignment -PrincipalId $managedIdentityId -RoleDefinitionId $roleId -DirectoryScopeId "/"