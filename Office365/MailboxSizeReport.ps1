<#
.SYNOPSIS
  Create report of all mailbox and archive sizes
.DESCRIPTION
  Collects all the mailbox and archive stats from Exchange Online users. By default it will also
  include the Shared Mailboxes. 
.EXAMPLE
  Get-MailboxSizeReport.ps1
  Generate the mailbox size report with Shared mailboxes, mailbox archive.
.EXAMPLE
  Get-MailboxSizeReport.ps1 -sharedMailboxes only
  Get only the shared mailboxes
.EXAMPLE
  Get-MailboxSizeReport.ps1 -sharedMailboxes no
  Get only the user mailboxes
.EXAMPLE
  Get-MailboxSizeReport.ps1 -archive:$false
  Get the mailbox size without the archive mailboxes
.EXAMPLE
  Get-MailboxSizeReport.ps1 -CSVpath c:\temp\report.csv
  Store CSV report in c:\temp\report.csv
.EXAMPLE
  Get-MailboxSizeReport.ps1 | Format-Table
  Print results for mailboxes in the console and format as table
.NOTES
  Version:        1.4
  Author:         R. Mens - LazyAdmin.nl
  Modified By:    Bradley Wyatt - The Lazy Administrator
  Creation Date:  23 sep 2021
  Modified Date:  14 sep 2022
  Purpose/Change: Check if we have an archive before running the numbers.
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
    HelpMessage = "Path to CSV file with email addresses"
  )]
  [string]$importCSV,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$CSVpath
)

Function ConnectTo-EXO {
  <#
    .SYNOPSIS
        Connects to EXO when no connection exists. Checks for EXO v2 module
  #>
  
  process {
    # Check if EXO is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement))
    {
      Write-Host "Exchange Online PowerShell v2 module is required, do you want to install it?" -ForegroundColor Yellow
      
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


    if ($null -ne (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) 
    {
	    # Check if there is a active EXO sessions
	    $psSessions = Get-PSSession | Select-Object -Property State, Name
	    If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
		    Connect-ExchangeOnline -UserPrincipalName $adminUPN -showBanner:$false
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
    if ($importCSV) {
      write-host "Using import CSV for email address" -ForegroundColor cyan

      $mailboxes = Import-CSV -path $importCSV -Header 'emailaddress' 
      
      ForEach($mailbox in $mailboxes) {
        Get-EXOMailbox -Identity $mailbox.emailaddress -Properties IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase | 
        Select-Object UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase
      }
    }else{
      switch ($sharedMailboxes)
      {
        "include" {$mailboxTypes = "UserMailbox,SharedMailbox"}
        "only" {$mailboxTypes = "SharedMailbox"}
        "no" {$mailboxTypes = "UserMailbox"}
      }

      Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails $mailboxTypes -Properties IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase | 
        Select-Object UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, IssueWarningQuota, ProhibitSendReceiveQuota, ArchiveQuota, ArchiveWarningQuota, ArchiveDatabase
    }
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
        "B"  {$sizeInGb = 0}
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
    $i = 0
    $mailboxes = Get-Mailboxes 
    $mailboxes | ForEach-Object {

      # Get mailbox size     
      $mailboxSize = Get-EXOMailboxStatistics -Identity $_.UserPrincipalName -Properties LastUserActionTime | Select-Object TotalItemSize,TotalDeletedItemSize,ItemCount,DeletedItemCount,LastUserActionTime

      if ($null -ne $mailboxSize) {
      
        # Get archive size if it exists and is requested
        $archiveSize = 0
        $archiveResult = $null

        if ($archive.IsPresent -and ($null -ne $_.ArchiveDatabase)) {
          $archiveResult = Get-EXOMailboxStatistics -UserPrincipalName $_.UserPrincipalName -Archive | Select-Object ItemCount,DeletedItemCount,@{Name = "TotalArchiveSize"; Expression = {$_.TotalItemSize.ToString().Split("(")[0]}}
          if ($null -ne $archiveResult) {
            $archiveSize = ConvertTo-Gb -size $archiveResult.TotalArchiveSize
          }
        }

        # Get Sent Items 
        $sentItems = Get-EXOMailboxFolderStatistics -Identity $_.UserPrincipalName -Folderscope sentitems | Where-Object {
          $_.FolderPath -eq "/Sent Items"
        } | Select-Object ItemsInFolderAndSubfolders,@{
          Name = "sentItemSize"; 
          Expression = {$_.FolderAndSubfolderSize.ToString().Split("(")[0]}
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
          "Mailbox Warning Quota (GB)" = ($_.IssueWarningQuota.ToString().Split("(")[0]).Split(" GB") | Select-Object -First 1
          "Max Mailbox Size (GB)" = ($_.ProhibitSendReceiveQuota.ToString().Split("(")[0]).Split(" GB") | Select-Object -First 1
          "Mailbox Free Space (GB)" = (($_.ProhibitSendReceiveQuota.ToString().Split("(")[0]).Split(" GB") | Select-Object -First 1) - (ConvertTo-Gb -size $mailboxSize.TotalItemSize.ToString().Split("(")[0])
          "Sent Items Size (GB)" = $(if($null -ne $sentItems) {ConvertTo-Gb -size $sentItems.sentItemSize} else {'-'})
          "Sent Items Count" = $(if($null -ne $sentItems) {$sentItems.ItemsInFolderAndSubfolders} else {'-'}) 
          "Archive Size (GB)" = $(if($null -ne $archiveResult) {ConvertTo-Gb -size $archiveResult.TotalArchiveSize} else {'-'})
          "Archive Items Count" = $(if($null -ne $archiveResult) {$archiveResult.ItemCount} else {'-'}) 
          "Archive Mailbox Free Space (GB)*" = $(if($null -ne $archiveResult) {(ConvertTo-Gb -size $_.ArchiveQuota.ToString().Split("(")[0]) - $archiveSize} else {'-'})
          "Archive Deleted Items Count" = $(if($null -ne $archiveResult) {$archiveResult.DeletedItemCount} else {'-'})
          "Archive Warning Quota (GB)" = $(if($null -ne $archiveResult) {($_.ArchiveWarningQuota.ToString().Split("(")[0]).Split(" GB") | Select-Object -First 1} else {'-'})
          "Archive Quota (GB)" = $(if($null -ne $archiveResult) {(ConvertTo-Gb -size $_.ArchiveQuota.ToString().Split("(")[0])} else {'-'})
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

If ($CSVpath) {
    # Get mailbox status
    Get-MailboxStats | Export-CSV -Path $CSVpath -NoTypeInformation -Encoding UTF8
    if ((Get-Item $CSVpath).Length -gt 0) {
        Write-Host "Report finished and saved in $CSVpath" -ForegroundColor Green
    } 
    else {
        Write-Host "Failed to create report" -ForegroundColor Red
    }
}
Else {
    Get-MailboxStats
}
