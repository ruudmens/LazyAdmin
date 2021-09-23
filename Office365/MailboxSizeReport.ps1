<#
.SYNOPSIS
  Create report of all mailbox and archive sizes

.DESCRIPTION
  Collects all the mailbox and archive stats from Exchange Online users. By default it will also
  include the Shared Mailboxes. 

.OUTPUTS
  CSV file

.NOTES
  Version:        0.1
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  03 march 2021
  Purpose/Change: Initial script development
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

    Get-EXOMailbox -ResultSize 10 -RecipientTypeDetails $mailboxTypes -Properties IssueWarningQuota,ProhibitSendReceiveQuota,ArchiveQuota,ArchiveWarningQuota,ArchiveDatabase | 
      select UserPrincipalName,DisplayName,PrimarySMTPAddress,RecipientType,IssueWarningQuota,ProhibitSendReceiveQuota,ArchiveQuota,ArchiveWarningQuota,ArchiveDatabase
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
      $mailboxSize = Get-EXOMailboxStatistics -UserPrincipalName $_.UserPrincipalName | Select TotalItemSize,TotalDeletedItemSize
      $archiveSize = 0

      # Get archive size if it exists and is requested
      if (($archive) -and ($_.ArchiveDatabase -ne $null)) {
        $result = Get-EXOMailboxStatistics -UserPrincipalName $_.UserPrincipalName -Archive | Select @{Name = "TotalArchiveSize"; Expression = {$_.TotalItemSize.ToString().Split("(")[0]}}
        $archiveSize = ConvertTo-Gb -size $result.TotalArchiveSize
      }  
    
      [pscustomobject]@{
        "Display Name" = $_.DisplayName
        "Emailaddress" = $_.PrimarySMTPAddress
        "Mailbox type" = $_.RecipientType
        "Total size (Gb)" = ConvertTo-Gb -size $mailboxSize.TotalItemSize.ToString().Split("(")[0]
        "Delete item size (Gb)" = ConvertTo-Gb -size $mailboxSize.TotalDeletedItemSize.ToString().Split("(")[0]
        "Max mailbox size (Gb)" = $_.ProhibitSendReceiveQuota.ToString().Split("(")[0]
        "Archive size (Gb)" = $archiveSize
        "Archive quota (Gb)" = ConvertTo-Gb -size $_.ArchiveQuota.ToString().Split("(")[0]
      }

      $currentUser = $_.DisplayName
      Write-Progress -Activity "Collecting mailbox status" -Status "Current Count: $i" -PercentComplete (($i / $mailboxes.Count) * 100) -CurrentOperation "Processing mailbox: $currentUser"
      $i++;
    }
  }
}

# Connect to Exchange Online
ConnectTo-EXO

# Get mailbox status
Get-MailboxStats | Export-CSV -Path $path -NoTypeInformation

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
