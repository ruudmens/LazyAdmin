<#
.SYNOPSIS
    This script connects to Microsoft Graph and SharePoint Admin (PnP) to audit unlicensed Microsoft 365 users and their OneDrive status.

.DESCRIPTION
    The script retrieves all unlicensed users (excluding guests) in your Microsoft 365 tenant using Microsoft Graph.
    It then checks if those users have a OneDrive site and collects site details using PnP PowerShell, including:
    - Storage usage (in GB)
    - Archive status

    The report helps identify OneDrive accounts that may soon be archived or deprovisioned due to license inactivity.

    The script outputs the results to:
    - The console (table view)
    - A timestamped CSV file (default path or specified with `-CSVPath`)

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  June 2025
  Purpose/Change: Initial release
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TenantName,

     [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter path to save the CSV file"
    )]
    [string]$CSVPath = ".\UnlicensedUsers-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

function Connect-ToMicrosoftGraph {
    $requiredScopes = @(
        "User.Read.All"
    )
    
    try {
        # Connect to Microsoft Graph with required scopes
        Connect-MgGraph -Scopes $requiredScopes -NoWelcome
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit
    }
}

function Connect-ToPnPOnline {
    try {
        $adminUrl = "https://$tenant-admin.sharepoint.com"
        Connect-PnPOnline -Url $adminUrl -UseWebLogin
        Write-Host "Successfully connected to SharePoint Admin: $adminUrl" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to PnP Online: $_"
        exit
    }
}

function Get-UnlicensedUsers {
    try {
        # Get all unlicensed users
        $unlicensedUsers = Get-MgUser -Filter "assignedLicenses/`$count eq 0 and userType eq 'Member'" `
                        -ConsistencyLevel eventual -CountVariable unlicensedUserCount -All
        Write-Host "Found $($unlicensedUsers.Count) unlicensed users" -ForegroundColor Green

        return $unlicensedUsers
    }
    catch {
        Write-Error "Failed to retrieve unlicensed users: $_"
        return $null
    }
}

function Get-OneDriveStatus {
    param (
        [Parameter(Mandatory = $true)]
        $unlicensedUsers
    )
    $result = @()

    foreach ($user in $unlicensedUsers) {
        $onedriveUrl = "https://$TenantName-my.sharepoint.com/personal/" + `
            $user.UserPrincipalName.Replace("@", "_").Replace(".", "_")

        try {
            $site = Get-PnPTenantSite -Url $onedriveUrl -ErrorAction Stop
            $result += [PSCustomObject]@{
                Owner             = $user.UserPrincipalName
                OwnerName         = "$($user.GivenName) $($user.Surname)"
                StorageUsageMB    = [math]::Round($site.StorageUsageCurrent / 1024, 2)
                ArchiveStatus     = $site.ArchiveStatus
            }
        } catch {
            Write-Host "No OneDrive found for user $($user.UserPrincipalName)"
        }
    }

    return $result
}

Connect-ToMicrosoftGraph
Connect-ToPnPOnline

# Get unlicensed users (excluding guests)
$unlicensedUsers = Get-UnlicensedUsers

# Get OneDrive status
$results = Get-OneDriveStatus -unlicensedUsers $unlicensedUsers

$results | Format-Table -AutoSize

# Export results to CSV
if ($null -ne $CSVPath) {
    $results | Export-Csv -Path $CSVPath -NoTypeInformation

    if ((Get-Item $CSVPath).Length -gt 0) {
        Write-Host "Report finished and saved in $CSVPath" -ForegroundColor Green

        # Open the CSV file
        Invoke-Item $CSVPath
    }else{
        Write-Host "Failed to create report" -ForegroundColor Red
    }
}
