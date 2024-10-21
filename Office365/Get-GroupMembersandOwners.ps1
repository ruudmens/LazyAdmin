<#
.SYNOPSIS
This script connects to Exchange Online and generates a report of members and owners for a specified Microsoft 365 Group.

.DESCRIPTION
The script performs the following actions:
1. Connects to Exchange Online using the provided admin credentials.
2. Retrieves information about members and owners of the specified Microsoft 365 Group.
3. Either displays the results in the console or exports them to a CSV file.

.PARAMETER adminUPN
The username of the Exchange Online or Global admin account.

.PARAMETER groupName
The name of the Microsoft 365 Group to report on.

.PARAMETER CSVpath
Optional. The path where the CSV file should be saved. If not provided, results are displayed in the console.

.EXAMPLE
.\Get-M365GroupMembersOwnersReport.ps1 -adminUPN admin@contoso.com -groupName "Marketing Team"

.EXAMPLE
.\Get-M365GroupMembersOwnersReport.ps1 -adminUPN admin@contoso.com -groupName "Marketing Team" -CSVpath "C:\Temp\MarketingTeamReport.csv"

.NOTES
Version:        1.0
Author:         R. Mens - LazyAdmin.nl
Creation Date:  2024-10-21
Purpose/Change: Initial script development
Link:           lazyadmin.nl

.FUNCTIONALITY
The script includes two main functions:

ConnectTo-EXO:
Connects to Exchange Online when no connection exists. Checks for the Exchange Online PowerShell v3 module and installs it if necessary.

Get-GroupMembersandOwners:
Retrieves information about members and owners of the specified Microsoft 365 Group, including name, title, department, link type (Member/Owner), and recipient type.
#>

[CmdletBinding()]
param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Enter the Exchange Online or Global admin username"
    )]
    [string]$adminUPN,

    [Parameter(
        Mandatory = $true,
        HelpMessage = "Enter the name of the group"
    )]
    [string]$groupName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter path to save the CSV file"
    )]
    [string]$CSVpath
)

Function ConnectTo-EXO {
<#
    .SYNOPSIS
    Connects to EXO when no connection exists. Checks for EXO v3 module
#>

process {
    # Check if EXO is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement))
    {
    Write-Host "Exchange Online PowerShell 3 module is requied, do you want to install it?" -ForegroundColor Yellow
    
    $install = Read-Host Do you want to install module? [Y] Yes [N] No 
    if($install -match "[yY]") 
    { 
        Write-Host "Installing Exchange Online PowerShell v3 module" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
    } 
    else
    {
        Write-Error "Please install EXO v3 module."
    }
    }

    if ($null -ne (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) 
    {
        # Check if there is a active EXO sessions
        $psSessions = Get-PSSession | Select-Object -Property State, Name
        If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
        Write-Host "Connecting to Exchange Online" -ForegroundColor Cyan
            Connect-ExchangeOnline -UserPrincipalName $adminUPN -ShowBanner:$false
        }
    }
    else{
    Write-Error "Please install EXO v3 module."
    }
}
}

Function Get-GroupMembersandOwners {
    PARAM(
        [parameter(Mandatory=$true)]
        $groupName
    )

    $members = Get-UnifiedGroupLinks -Identity $groupName -LinkType member
    $owners = Get-UnifiedGroupLinks -Identity $groupName -LinkType owner

    $results = @()

    $results += $members | Where-Object { $owners.Identity -notcontains $_.Identity } | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.DisplayName
            Title = $_.Title
            Department = $_.Department
            LinkType = "Member"
            RecipientType = $_.RecipientType
        }
    }

    $results += $owners | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.DisplayName
            Title = $_.Title
            Department = $_.Department
            LinkType = "Owner"
            RecipientType = $_.RecipientType
        }
    }

    return $results | Sort-Object Name
}
  
# Connect to Exchange Online
ConnectTo-EXO

# Get all Microsoft 365 Groups
If ([string]::IsNullOrEmpty($CSVpath)) {
    Get-GroupMembersandOwners -groupName $groupName | Format-Table
} 
Else {
    Get-GroupMembersandOwners -groupName $groupName | Export-CSV -Path $CSVpath -NoTypeInformation -Encoding UTF8
    if ((Get-Item $CSVpath).Length -gt 0) {
        Write-Host "Report finished and saved in $CSVpath" -ForegroundColor Green
    } 
    else {
        Write-Host "Failed to create report" -ForegroundColor Red
    }
}