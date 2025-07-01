<#
    .SYNOPSIS
    Updates Microsoft 365 user accounts based on values from a CSV file using Microsoft Graph PowerShell.

    .DESCRIPTION
    This script connects to Microsoft Graph, reads a CSV file with user data, and updates the Job Title and Department fields for each user. 
    It uses UserPrincipalName as the primary identifier and falls back to DisplayName if UPN is missing.
    Only non-empty fields in the CSV are applied to avoid overwriting existing values with blanks.

    .NOTES
    Version:        1.0
    Author:         R. Mens - LazyAdmin.nl
    Creation Date:  1 jul 2025
    Purpose/Change: Initial script development
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$CSVPath
)

function ConnectTo-MgGraph {
    if (-not (Get-MgContext)) {
        if (Get-InstalledModule Microsoft.Graph) {
            # Connect to MSFT Graph
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
            Connect-MgGraph -Scopes "User.ReadWrite.All" -NoWelcome
        }else{
            Write-Host "Microsoft Graph module not found - please install it" -ForegroundColor Black -BackgroundColor Yellow
            exit
        }
    }
    else {
        Write-Host "Already connected to Microsoft Graph." -ForegroundColor Green
    }
}

function Update-UsersFromCsv {
    param (
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        Write-Error "CSV file not found: $Path"
        return
    }

    $csv = Import-Csv -Path $Path

    foreach ($row in $csv) {
        # Find the user by UPN or fallback to DisplayName
        if (![string]::IsNullOrEmpty($row.UserPrincipalName)) {
            $user = Get-MgUser -UserId $row.UserPrincipalName -ErrorAction SilentlyContinue
        }
        elseif (![string]::IsNullOrEmpty($row.DisplayName)) {
            $user = Get-MgUser -Filter "displayName eq '$($row.DisplayName)'" -ErrorAction SilentlyContinue
        }
        else {
            Write-Warning "Missing UserPrincipalName and DisplayName in row: $($row | Out-String)"
            continue
        }

        if (-not $user) {
            Write-Warning "User not found: $($row.UserPrincipalName ?? $row.DisplayName)"
            continue
        }

        $updateProps = @{}
        # Define each column (field) that you want to update
        # We check if a field is set or not. When empty, we skip it, leaving the 
        # original value in Microsoft Entra
        if (![string]::IsNullOrEmpty($row.JobTitle)) {
            $updateProps["JobTitle"] = $row.JobTitle
        }
        if (![string]::IsNullOrEmpty($row.Department)) {
            $updateProps["Department"] = $row.Department
        }

        # Check if we need to update fields for this user
        # and update the user attributes
        if ($updateProps.Count -gt 0) {
            try {
                Update-MgUser -UserId $user.Id @updateProps
                Write-Host "Updated: $($user.UserPrincipalName)" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to update $($user.UserPrincipalName): $_"
            }
        }
        else {
            Write-Host "No updates for $($user.UserPrincipalName)" -ForegroundColor Yellow
        }
    }
}

# Run the script
ConnectTo-MgGraph
Update-UsersFromCsv -Path $CsvPath