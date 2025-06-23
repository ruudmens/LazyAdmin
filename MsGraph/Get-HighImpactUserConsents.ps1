<#
.SYNOPSIS
    Lists user-consented Azure AD applications that request high-impact permissions.

.DESCRIPTION
    Connects to Microsoft Graph and retrieves OAuth2 permission grants where users have
    consented to third-party apps. Filters out low-impact scopes like openid, email,
    profile, offline_access, and User.Read. Only displays apps with elevated access
    granted by end users.

.NOTES
    Version:        1.0
    Author:         R. Mens - LazyAdmin.nl
    Creation Date:  June 2025
    Purpose/Change: Initial release
#>

# Connect with minimal required scopes
Connect-MgGraph -Scopes "Directory.Read.All", "User.Read.All", "Application.Read.All"

# Define low-impact scopes to exclude
$lowImpact = @("openid", "email", "profile", "offline_access", "User.Read")

# Get user-consented permission grants (PrincipalId is not null)
$grants = Get-MgOauth2PermissionGrant -All | Where-Object { $_.PrincipalId -ne $null }

# Prepare result list
$result = @()

foreach ($grant in $grants) {
    # Split the scope string into individual scopes
    $scopes = $grant.Scope.Trim() -split " "

    # Filter out low-impact scopes
    $highImpact = $scopes | Where-Object { $lowImpact -notcontains $_ }

    # Skip if there are no high-impact scopes
    if ($highImpact.Count -eq 0) { continue }

    # Get user and app info
    $user = Get-MgUser -UserId $grant.PrincipalId
    $app  = Get-MgServicePrincipal -ServicePrincipalId $grant.ClientId

    # Store result
    $result += [PSCustomObject]@{
        UserPrincipal = $user.UserPrincipalName
        AppName       = $app.DisplayName
        HighImpactScopes = ($highImpact -join ", ")
        ConsentType   = $grant.ConsentType
    }
}

# Display the filtered results
$result | Format-Table -AutoSize