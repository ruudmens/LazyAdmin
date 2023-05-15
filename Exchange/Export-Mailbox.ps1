<#
 .SYNOPSIS
  Export all mailboxes 

.DESCRIPTION
  This script isn't written by me, but shared in the comments of the article by Simon. I haven't tested it, use it at your own risk

.NOTES
  Version:        1.0
  Author:         Simon
  Creation Date:  
  Purpose/Change:
  Link:           https://lazyadmin.nl/office-365/export-office-365-mailbox-to-pst/#comment-9111
#>

# Cmdlet binding
[CmdletBinding()]
Param (
  [Parameter(Mandatory = $true)]
  [String]$SharePointURL,
  [Parameter(Mandatory = $true)]
  [String]$DataFile
)

# Modules

Import-Module -Name ExchangeOnlineManagement
Install-Module PnP.PowerShell -Scope CurrentUser -RequiredVersion 1.12

# Set error handling

$ErrorActionPreference = “Stop”

# Functions

function Write-Exception {
  [CmdletBinding()]
  Param([Parameter(Mandatory)][string]$Message, [Parameter(Mandatory)][string]$Action)

  Begin {}

  Process {
    $host.UI.WriteErrorLine(“`r`n[ERROR] $Message $Action`r`n”)
  }

  End {}
}

# Validate input

if (-not (Test-Path $DataFile)) {
  Write-Exception -Message “Failed to find data file. $($_.Exception.Message)” -Action “Check data file path exists.”
  Exit
}

if (-not ($SharePointURL -match “^https:\/\/[a-zA-Z]+\.sharepoint\.com$”)) {
  Write-Exception -Message “Invalid SharePoint URL. $($_.Exception.Message)” -Action “SharePoint URL format must be https://tenantname.sharepoint.com”
  Exit
}

# Additional functions

function MailboxExists {
  [CmdletBinding()]
  Param([Parameter(Mandatory)][string]$Email)

  # Return true if the mailbox exists

  Return [boolean](Get-mailbox -Identity $Email -ErrorAction SilentlyContinue)
}

function GetOneDrivePath {
  [CmdletBinding()]
  Param([Parameter(Mandatory)][string]$UPN)

  # Get SharePoint sites for the user

  [string]$result = Get-PnPUserProfileProperty -Account $UPN | Select -ExpandProperty PersonalUrl -ErrorAction SilentlyContinue
  [string]$sharePointPersonalURL = $SharePointURL -Replace (“.sharepoint.com”, “-my.sharepoint.com/personal”)

  # Filter out any sites that are not OneDrive

  if ($result -ne $null) {
    if ( -not ($result.StartsWith($sharePointPersonalURL)) ) { $result = $null }
  }

  # Return the URL for OneDrive

  Return $result
}

function Cleanup {
  if ( ($null -ne $psContextExchangeOnline) -or ($null -ne $psContextIPPSSession) ) {
    Disconnect-ExchangeOnline -Confirm:$false | Out-Null
  }

  if ($null -ne $psContextPnPOnline) {
    Disconnect-PnPOnline | Out-Null
  }
}

# Main

Write-Host “`r`nArchive Microsoft 365 Users`r`n”

# Connect to ExchangeOnline

[object]$psContextExchangeOnline = $null

try {
  Write-Host “Connecting to ExchangeOnline…” -ForegroundColor Yellow
  Connect-ExchangeOnline -ShowBanner:$false | Out-Null
  $psContextExchangeOnline = Get-ConnectionInformation
}
catch {
  Write-Exception -Message “Failed to connect to ExchangeOnline. $($_.Exception.Message)” -Action “Check internet connection and credentials.”
  Cleanup
  Exit
}

# Connect to IPPSSession

[object]$psContextIPPSSession = $null

try {
  Write-Host “Connecting to IPPSSession…” -ForegroundColor Yellow
  Connect-IPPSSession | Out-Null
  $psContextIPPSSession = Get-ConnectionInformation
}
catch {
  Write-Exception -Message “Failed to connect to IPPSSession. $($_.Exception.Message)” -Action “Check internet connection and credentials.”
  Cleanup
  Exit
}

# Connect to PnPOnline

[object]$psContextPnPOnline = $null

try {
  Write-Host “Connecting to PnPOnline…” -ForegroundColor Yellow
  [string]$sharePointAdminURL = $SharePointURL -Replace (“.sharepoint.com”, “-admin.sharepoint.com”)
  Connect-PnPOnline $sharePointAdminURL -Interactive | Out-Null
  $psContextPnPOnline = Get-PnpConnection
}
catch {
  Write-Exception -Message “Failed to connect to PnPOnline. $($_.Exception.Message)” -Action “Check internet connection and credentials.”
  Cleanup
  Exit
}

# Make sure we are connected and process the users

if ( ($null -ne $psContextExchangeOnline) -and ($null -ne $psContextIPPSSession) -and ($null -ne $psContextPnPOnline) ) {
  # Import user data and setup main hash tables

  [object]$users = Import-CSV $DataFile
  [hashtable]$emailBatches = @{}
  [hashtable]$oneDriveBatches = @{}

  # Process next user

  foreach ($user in $users) {
    # Get user details from the CSV

    [string]$batch = $user.Batch
    [string]$email = $user.Email
    [string]$upn = $user.UPN

    Write-Host “Processing user $email…” -ForegroundColor Yellow

    # Initialise

    [string[]]$emailBatch = @()
    [string[]]$oneDriveBatch = @()

    # Get existing entries from hash table if the batch exists

    if ($emailBatches.ContainsKey($batch)) {
      $emailBatch = $emailBatches[$batch]
    }

    if ($oneDriveBatches.ContainsKey($batch)) {
      $oneDriveBatch = $oneDriveBatches[$batch]
    }

    # Add user to the batch and update the hash tables

    if (MailboxExists -Email $email) {
      Write-Host “User $email has email. Adding to email batch $batch…” -ForegroundColor Yellow
      $emailBatch += $email
      $emailBatches[$batch] = $emailBatch
    }

    [string]$oneDrivePath = GetOneDrivePath -UPN $upn

    if ($oneDrivePath -ne “” -and $oneDrivePath -ne $null) {
      Write-Host “User $upn has OneDrive. Adding to OneDrive batch $batch…” -ForegroundColor Yellow
      $oneDriveBatch += $oneDrivePath
      $oneDriveBatches[$batch] = $oneDriveBatch
    }
  }

  # Create the compliance searches

  [string]$archiveDate = Get-Date -Format (“yyyyMMdd”)

  try {
    foreach ($item in $emailBatches.GetEnumerator() | Sort-Object -Property Name) {
      [string]$searchName = “ArchiveEmail_$($archiveDate)_Batch_$($item.Name)”
      Write-Host “Creating Compliance Search $searchName…” -ForegroundColor Yellow
      New-ComplianceSearch -Name $searchName -ExchangeLocation $item.Value
    }
  }
  catch {
    Write-Exception -Message “Failed to create email batch $searchName. $($_.Exception.Message)” -Action “Check the reported error.”
    Cleanup
    Exit
  }

  try {
    foreach ($item in $oneDriveBatches.GetEnumerator() | Sort-Object -Property Name) {
      [string]$searchName = “ArchiveOneDrive_$($archiveDate)_Batch_$($item.Name)”
      Write-Host “Creating Compliance Search $searchName…” -ForegroundColor Yellow
      New-ComplianceSearch -Name $searchName -SharePointLocation $item.Value
    }
  }
  catch {
    Write-Exception -Message “Failed to create OneDrive batch $searchName. $($_.Exception.Message)” -Action “Check the reported error.”
    Cleanup
    Exit
  }

  # Cleanup

  Cleanup
}
else {
  Cleanup
  Write-Exception -Message “Not connected to ExchangeOnline and/or IPPSSession and/or PnPOnline.” -Action “Check internet connection and credentials.”
}