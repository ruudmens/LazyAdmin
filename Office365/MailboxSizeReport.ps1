<#
.SYNOPSIS
  Create report of all mailbox and archive sizes

.DESCRIPTION
  Collects all the mailbox and archive stats from Exchange Online users. By default it will also
  include the Shared Mailboxes. 

.EXAMPLE
  Get-MailboxSizeReport.ps1 -adminUPN johndoe@contoso.com

  Generate the mailbox size report with Shared mailboxes, mailbox archive and store 
  the csv file in the script root location.

.EXAMPLE
  Get-MailboxSizeReport.ps1 -adminUPN johndoe@contoso.com -sharedMailboxes only

  Get only the shared mailboxes

.EXAMPLE
  Get-MailboxSizeReport.ps1 -adminUPN johndoe@contoso.com -sharedMailboxes no

  Get only the user mailboxes

.EXAMPLE
  Get-MailboxSizeReport.ps1 -adminUPN johndoe@contoso.com -archive:$false

  Get the mailbox size without the archive mailboxes

.EXAMPLE
  Get-MailboxSizeReport.ps1 -adminUPN johndoe@contoso.com -path c:\temp\report.csv

  Store CSV report in c:\temp\report.csv

.NOTES
  Version:        1.2
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  23 sep 2021
  Purpose/Change: Check if we have a mailbox, before running the numbers
  Link:           https://lazyadmin.nl/powershell/office-365-mailbox-size-report
#>

param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter the Exchange Online or Global admin username"
  )]
  [string]$adminUPN,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Get (only) Shared Mailboxes or not. Default include them"
  )]
  [ValidateSet("no", "only", "include")]
  [string]$sharedMailboxes = "include",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Include Archive mailboxes"
  )]
  [switch]$archive = $true,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\MailboxSizeReport-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function ConnectTo-EXO {
  <#
    .SYNOPSIS
        Connects to EXO when no connection exists. Checks for EXO v2 module
  #>
  
  process {
    # Check if EXO is installed and connect if no connection exists
    if ((Get-Module -ListAvailable -Name ExchangeOnlineManagement) -eq $null)
    {
      Write-Host "Exchange Online PowerShell v2 module is requied, do you want to install it?" -ForegroundColor Yellow
      
      $install = Read-Host Do you want to install module? [Y] Yes [N] No 
      if($install -match "[yY]") 
      { 
        Write-Host "Installing Exchange Online PowerShell v2 module" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
      } 
      else
      {
	      Write-Error "Please install EXO v2 module."
      }
    }


    if ((Get-Module -ListAvailable -Name ExchangeOnlineManagement) -ne $null) 
    {
	    # Check if there is a active EXO sessions
	    $psSessions = Get-PSSession | Select-Object -Property State, Name
	    If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
		    Connect-ExchangeOnline -UserPrincipalName $adminUPN
	    }
    }
    else{
      Write-Error "Please install EXO v2 module."
    }
  }
}

Function Get-Mailboxes {
  <#
    .SYNOPSIS
        Get all the mailboxes for the report
  #>
  process {
    switch ($sharedMailboxes)
    {
      "include" {$mailboxTypes = "UserMailbox,SharedMailbox"}
      "only" {$mailboxTypes = "SharedMailbox"}
      "no" {$mailboxTypes = "UserMailbox"}
    }

    Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails $mailboxTypes -Properties IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase | 
      select UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase
  }
}

Function ConvertTo-Gb {
  <#
    .SYNOPSIS
        Convert mailbox size to Gb for uniform reporting.
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    [string]$size
  )
  process {
    if ($size -ne $null) {
      $value = $size.Split(" ")

      switch($value[1]) {
        "GB" {$sizeInGb = ($value[0])}
        "MB" {$sizeInGb = ($value[0] / 1024)}
        "KB" {$sizeInGb = ($value[0] / 1024 / 1024)}
      }

      return [Math]::Round($sizeInGb,2,[MidPointRounding]::AwayFromZero)
    }
  }
}


Function Get-MailboxStats {
  <#
    .SYNOPSIS
        Get the mailbox size and quota
  #>
  process {
    $mailboxes = Get-Mailboxes
    $i = 0

    $mailboxes | ForEach {

      # Get mailbox size     
      $mailboxSize = Get-MailboxStatistics -identity $_.UserPrincipalName | Select TotalItemSize,TotalDeletedItemSize,ItemCount,DeletedItemCount,LastUserActionTime

      if ($mailboxSize -ne $null) {
      
        # Get archive size if it exists and is requested
        $archiveSize = 0
        $archiveResult = $null

        if ($archive.IsPresent -and ($_.ArchiveDatabase -ne $null)) {
          $archiveResult = Get-EXOMailboxStatistics -UserPrincipalName $_.UserPrincipalName -Archive | Select ItemCount,DeletedItemCount,@{Name = "TotalArchiveSize"; Expression = {$_.TotalItemSize.ToString().Split("(")[0]}}
          if ($archiveResult -ne $null) {
            $archiveSize = ConvertTo-Gb -size $archiveResult.TotalArchiveSize
          }else{
            $archiveSize = 0
          }
        }  
    
        [pscustomobject]@{
          "Display Name" = $_.DisplayName
          "Email Address" = $_.PrimarySMTPAddress
          "Mailbox Type" = $_.RecipientTypeDetails
          "Last User Action Time" = $mailboxSize.LastUserActionTime
          "Total Size (GB)" = ConvertTo-Gb -size $mailboxSize.TotalItemSize.ToString().Split("(")[0]
          "Deleted Items Size (GB)" = ConvertTo-Gb -size $mailboxSize.TotalDeletedItemSize.ToString().Split("(")[0]
          "Item Count" = $mailboxSize.ItemCount
          "Deleted Items Count" = $mailboxSize.DeletedItemCount
          "Mailbox Warning Quota (GB)" = $_.IssueWarningQuota.ToString().Split("(")[0]
          "Max Mailbox Size (GB)" = $_.ProhibitSendReceiveQuota.ToString().Split("(")[0]
          "Archive Size (GB)" = $archiveSize
          "Archive Items Count" = $archiveResult.ItemCount
          "Archive Deleted Items Count" = $archiveResult.DeletedItemCount
          "Archive Warning Quota (GB)" = $_.ArchiveWarningQuota.ToString().Split("(")[0]
          "Archive Quota (GB)" = ConvertTo-Gb -size $_.ArchiveQuota.ToString().Split("(")[0]
        }

        $currentUser = $_.DisplayName
        Write-Progress -Activity "Collecting mailbox status" -Status "Current Count: $i" -PercentComplete (($i / $mailboxes.Count) * 100) -CurrentOperation "Processing mailbox: $currentUser"
        $i++;
      }
    }
  }
}

# Connect to Exchange Online
ConnectTo-EXO

# Get mailbox status
Get-MailboxStats | Export-CSV -Path $path -NoTypeInformation -Encoding UTF8

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green
}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}


# Close Exchange Online Connection
$close = Read-Host Close Exchange Online connection? [Y] Yes [N] No 

if ($close -match "[yY]") {
  Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}
