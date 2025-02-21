
<#
.SYNOPSIS
    Generates a report of all users with administrative roles in Microsoft 365 using Microsoft Graph.

.DESCRIPTION
    This script retrieves all directory roles from Microsoft 365 and identifies users assigned to these roles.
    It collects user information including display name, role assignments, account status, and last sign-in time.
    Results are exported to a CSV file for further analysis.

.EXAMPLE
    .\Get-M365UserWithAdminRoles.ps1 -Path "C:\Reports\AdminRoles.csv"
    Runs the script and saves the report to the specified path.

.NOTES
    Requires the Microsoft.Graph PowerShell module
    Required permissions: RoleManagement.Read.Directory, User.Read.All, AuditLog.Read.All

.NOTES
    Name: Get-M365UserWithAdminRoles
    Author: R. Mens - LazyAdmin.nl
    Version: 1.0
    DateCreated: Feb 2025
    Purpose/Change: Init

.LINK
    https://lazyadmin.nl
#>

param (
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Get only users with an admin role"
      )]
    [switch]$usersOnly = $true,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter path to save the CSV file"
      )]
      [string]$path = ".\Users-with-admin-role-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

# Check if MS Graph module is installed
if (Get-InstalledModule Microsoft.Graph) {
    # Connect to MS Graph
    Connect-MgGraph -Scopes "RoleManagement.Read.Directory", "User.Read.All" -NoWelcome
}else{
    Write-Host "Microsoft Graph module not found - please install it" -ForegroundColor Black -BackgroundColor Yellow
    exit
}

# Initialize an array to store the results
$results = @()

# Get all directory roles and Loop through each role
Get-MgDirectoryRole | ForEach {

    # Get members of the current role
    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $_.Id
    
    # Process each member
    foreach ($member in $members) {

        # Only process user objects (skip groups or service principals)
        if ($usersOnly -and ($member.AdditionalProperties.'@odata.type' -ne '#microsoft.graph.user')) {
            continue
        }
        # Get detailed user information including sign-in activity
        $user = Get-MgUser -UserId $member.Id -Property "Id,UserPrincipalName,DisplayName,AccountEnabled"
    
        # Create new entry for each user-role combination
        $results += [PSCustomObject]@{
            DisplayName = $user.DisplayName
            Role = $_.DisplayName
            AccountEnabled = $user.AccountEnabled
            UserPrincipalName = $user.UserPrincipalName
        }
    }
}

# Export results to CSV
$results | Sort-Object UserPrincipalName, Role | Out-GridView # Export-Csv -Path $path -NoTypeInformation -Encoding Utf8