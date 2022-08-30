
Connect-MgGraph -Scopes "User.Read.All","Application.ReadWrite.All","AppRoleAssignment.ReadWrite.All"

# Get the service principal for the app you want to assign the user to
$servicePrincipal = Get-MgServicePrincipal -Filter "Displayname eq 'APPLICATION NAME'"

# Get all users that are already assigned to APPLICATION NAME
$atlassianUsers = Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId $servicePrincipal.Id -All | Select -ExpandProperty PrincipalId

# Get all licensedUsers
$licensedUsers =  Get-MgUser -All -Filter 'AccountEnabled eq true' -Property AssignedLicenses,id,displayname | Where-Object ({$_.AssignedLicenses}) | Select displayname,id

# Compare lists
$newUsers = $licensedUsers | Where-Object { $_.id -notin $atlassianUsers }

ForEach ($user in $newUsers) {
  Try {
    $params = @{
      PrincipalId = $user.id
	    ResourceId = $servicePrincipal.Id
	    AppRoleId = $servicePrincipal.Approles[0].id
    }

    New-MgUserAppRoleAssignment -UserId $user.id -BodyParameter $params

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