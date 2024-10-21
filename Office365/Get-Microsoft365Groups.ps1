<#
.SYNOPSIS
    This script connects to Exchange Online and generates a report of all Microsoft 365 Groups, either displaying the results or exporting them to a CSV file.
.DESCRIPTION
    The script performs the following actions:

    Connects to Exchange Online using the provided admin credentials.
    Retrieves information about all Microsoft 365 Groups.
    Either displays the results in the console or exports them to a CSV file.

.PARAMETER adminUPN
    The username of the Exchange Online or Global admin account.
.PARAMETER CSVpath
    Optional. The path where the CSV file should be saved.
.EXAMPLE
    .\Get-MicrosoftGroups.ps1 -adminUPN admin@contoso.com -CSVpath "C:\Temp\GroupsReport.csv"
.NOTES
    Version:        1.0
    Author:         R. Mens - LazyAdmin.nl
    Creation Date:  2024-10-21
    Purpose/Change: Init
    Link:           lazyadmin.nl
.FUNCTIONALITY
    The script includes two main functions:
    
    ConnectTo-EXO:
    Connects to Exchange Online when no connection exists. Checks for the Exchange Online PowerShell v3 module and installs it if necessary.

    Get-Groups:
    Retrieves information about all Microsoft 365 Groups, including display name, access type, primary SMTP address, owner count, member count, external member count, SharePoint site URL, managed by, and creation date.
#>

[CmdletBinding()]
param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = "Enter the Exchange Online or Global admin username"
    )]
    [string]$adminUPN,

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

Function Get-Groups {

    $properties = 
        "DisplayName",
        "AccessType",
        "PrimarySmtpAddress",
        @{
            Name = 'GroupOwnerCount' 
            Expression = { $_.ManagedBy.count }
        },
        "GroupMemberCount",
        "GroupExternalMemberCount",
        "SharePointSiteUrl",
        "ManagedBy",
        "WhenCreated"

    # Get all groups without Owner
    Get-UnifiedGroup | Select-Object -Property $properties 
}
  
# Connect to Exchange Online
ConnectTo-EXO

# Get all Microsoft 365 Groups
If ($CSVpath) {
    # Get mailbox status
    Get-Groups | Export-CSV -Path $CSVpath -NoTypeInformation -Encoding UTF8
    if ((Get-Item $CSVpath).Length -gt 0) {
        Write-Host "Report finished and saved in $CSVpath" -ForegroundColor Green
    } 
    else {
        Write-Host "Failed to create report" -ForegroundColor Red
    }
}
Else {
    Get-Groups | ft
}