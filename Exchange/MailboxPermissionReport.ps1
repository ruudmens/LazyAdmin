<#
.SYNOPSIS
  Create report of all mailbox permissions for on-prem exchange server

.DESCRIPTION
  Get all mailbox permissions, including folder permissions for all or a selected group of users

.EXAMPLE
  .\MailboxPermissionReport.ps1 

  Generate the mailbox report with Shared mailboxes, store the csv file in the script root location.

.EXAMPLE
  .\MailboxPermissionReport.ps1 -sharedMailboxes only

  Get only the shared mailboxes

.EXAMPLE
  .\MailboxPermissionReport.ps1 -sharedMailboxes no

  Get only the user mailboxes

.EXAMPLE
  .\MailboxPermissionReport.ps1 -folderPermissions:$false

  Get the mailbox permissions without the folder (inbox and calendar) permissions

.EXAMPLE
  .\MailboxPermissionReport.ps1 -UserPrincipalName jane@contoso.com,alex@contoso.com

  Get the mailbox permissions for a selection of users

.EXAMPLE
  .\MailboxPermissionReport.ps1 -displayNames:$false

  Don't get the full displayname for each permissions (to speed up the script)

 .EXAMPLE
  .\MailboxPermissionReport.ps1 -csvFile "c:\temp\mailboxusers.csv"

  Using CSV file with list of users to get permissions from. Use the following format:
  UserPrincipalName,Display Name
  AdeleV@contoso.onmicrosoft.com,Adele Vance
  GradyA@contoso.onmicrosoft.com,Grady Archie


.EXAMPLE
  MailboxPermissionReport.ps1 -adminUPN johndoe@contoso.com -path c:\temp\report.csv

  Store CSV report in c:\temp\report.csv

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  24-03-2022
  Purpose/Change: Add CSV Import method
  Link:           https://lazyadmin.nl/powershell/get-mailbox-permissions-with-powershell/
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter a single UserPrincipalName or a comma separted list of UserPrincipalNames"
    )]
  [string[]]$UserPrincipalName,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Get (only) Shared Mailboxes or not. Default include them"
  )]
  [ValidateSet("no", "only", "include")]
  [string]$sharedMailboxes = "include",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Include Folder Permissions"
  )]
  [switch]$folderPermissions = $true,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Show display names"
  )]
  [switch]$displayNames = $true,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to CSV"
  )]
  [string]$csvFile,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\MailboxPermissionReport-$((Get-Date -format "MM-dd-yyyy").ToString()).csv"
)


#
# Configuration
#

# Set the propers name for your mailbox folders
# You can find all folders for a mailbox with Get-EXOMailboxFolderStatistics -identity <emailaddress@contoso.com> | ft 

$inboxFolderName = "inbox"  # Default "inbox"
$calendarFolderName = "calendar"  # Default "calendar"

Function Find-LargestValue {
  <#
    .SYNOPSIS
        Find the value with the most records
  #>
  param(
    [Parameter(Mandatory = $true)]$sob,
    [Parameter(Mandatory = $true)]$fa,
    [Parameter(Mandatory = $true)]$sa,
    [Parameter(Mandatory = $true)]$ib,
    [Parameter(Mandatory = $true)]$ca
  )
  
  Write-host "sob $sob  fa $fa  sa $sa  ib $ib  ca $ca";

  if ($sob -gt $fa -and $sob -gt $sa -and $sob -gt $ib -and $sob -gt $ca) {return $sob}
  elseif ($fa -gt $sa -and $fa -gt $ib -and $fa -gt $ca) {return $fa}
  elseif ($sa -gt $ib -and $sa -gt $ca) {return $sa}
  elseif ($ib -gt $ca) {return $ib}
  else {return $ca}
}

Function Get-DisplayName {
  <#
    .SYNOPSIS
      Get the full displayname (if requested) or return only the userprincipalname
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    $identity
  )

  if ($displayNames.IsPresent) {
    Try {
      return (Get-Mailbox -Identity $identity -ErrorAction Stop).DisplayName
    }
    Catch{
      return $identity
    }
  }else{
    return $identity.ToString().Split("@")[0]
  }
}

Function Get-SingleUser {
  <#
    .SYNOPSIS
      Get only the requested mailbox
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    $identity
  )

  Get-Mailbox -Identity $identity | 
      Select-Object UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, GrantSendOnBehalfTo, ForwardingSMTPAddress
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

    Get-Mailbox -ResultSize unlimited -RecipientTypeDetails $mailboxTypes  | 
      Select-Object UserPrincipalName, DisplayName, PrimarySMTPAddress, RecipientType, RecipientTypeDetails, GrantSendOnBehalfTo, ForwardingSMTPAddress
  }
}

Function Get-SendOnBehalf {
  <#
    .SYNOPSIS
        Get Display name for each Send on Behalf entity
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    $mailbox
  )

  # Get Send on Behalf
  $SendOnBehalfAccess = @();
  if ($null -ne $mailbox.GrantSendOnBehalfTo) {
    
    # Get a proper displayname of each user
    $mailbox.GrantSendOnBehalfTo | ForEach {
      $sendOnBehalfAccess += Get-DisplayName -identity $_
    }
  }
  return $SendOnBehalfAccess
}

Function Get-SendAsPermissions {
  <#
    .SYNOPSIS
        Get all users with Send as Permissions
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    $identity
  )
  $users = Get-ADPermission -Identity $identity | where {($_.ExtendedRights -like "*Send*") -and -not ($_.User -like "NT AUTHORITY\SELF") -and -not ($_.User -like "s-1-5-21*")} | % {$_.User}

  $sendAsUsers = @();
  
  # Get a proper displayname of each user
  $users | ForEach {
    $sendAsUsers += Get-DisplayName -identity $_.Trustee
  }
  return $sendAsUsers
}

Function Get-FullAccessPermissions {
  <#
    .SYNOPSIS
        Get all users with Read and manage (full access) permissions
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    $identity
  )
  
  $users = Get-MailboxPermission -Identity $identity | Where-Object {($_.IsInherited -eq $False) -and -not ($_.User -match "NT AUTHORITY")} | 
    Select User,Identity,@{Name="AccessRights";Expression={$_.AccessRights}} | ForEach-Object {$_.User}

  $fullaccessUsers = @();
  
  # Get a proper displayname of each user
  $users | ForEach {
    $fullaccessUsers += Get-DisplayName -identity $_.User
  }
  return $fullaccessUsers
}

Function Get-FolderPermissions {
  <#
    .SYNOPSIS
      Get Inbox folder permisions
  #>
  param(
    [Parameter(Mandatory = $true)] $identity,
    [Parameter(Mandatory = $true)] $folder
  )
  
  $return = @{
    users = @()
    permission = @()
    delegated = @()
  }

  Try {
    $ErrorActionPreference = "Stop"; #Make all errors terminating
    $users = Get-MailboxFolderPermission -Identity "$($identity):\$($folder)" | 
      Where-Object { -not ($_.User -match "Default") -and -not ($_.AccessRights -match "None")}
  }
  Catch{
    Write-Error "Unable to get Mailbox folder permission $folder"
    return $return
  }
  Finally{
   $ErrorActionPreference = "Continue"; #Reset the error action pref to default
  }

  $folderUsers = @();
  $folderAccessRights = @();
  $folderDelegated = @();
  
  # Get a proper displayname of each user
  $users | ForEach {
    $folderUsers += Get-DisplayName -identity $_.User
    $folderAccessRights += $_.AccessRights
    $folderDelegated += $_.SharingPermissionFlags
  }

  $return.users = $folderUsers
  $return.permission = $folderAccessRights
  $return.delegated = $folderDelegated

  return $return
}

Function Get-AllMailboxPermissions {
  <#
    .SYNOPSIS
      Get all the permissions of each mailbox
        
      Permission are spread into 4 parts.
      - Read and Manage permission
      - Send as Permission
      - Send on behalf of permission
      - Folder permissions (inbox and calendar set by the user self)
  #>
  process {

    if ($UserPrincipalName) {
      
      Write-Host "Collecting mailboxes" -ForegroundColor Cyan
      $mailboxes = @()

      # Get the requested mailboxes
      foreach ($user in $UserPrincipalName) {
        Write-Host "- Get mailbox $user" -ForegroundColor Cyan
        $mailboxes += Get-SingleUser -identity $user
      }
    }elseif ($csvFile) {
      
      Write-Host "Using CSV file" -ForegroundColor Cyan
      $mailboxes = @()

      # Test CSV file path
      if (Test-Path $csvFile) {

        # Read CSV File
        Import-Csv $csvFile | ForEach {
          Write-Host "- Get mailbox $($_.UserPrincipalName)" -ForegroundColor Cyan
          $mailboxes += Get-SingleUser -identity $_.UserPrincipalName
        }
      }else{
        Write-Host "Unable to find CSV file $csvFile" -ForegroundColor black -BackgroundColor Yellow
      }
    }else{
      Write-Host "Collecting mailboxes" -ForegroundColor Cyan
      $mailboxes = Get-Mailboxes
    }
    
    $i = 0
    Write-Host "Collecting permissions" -ForegroundColor Cyan
    $mailboxes | ForEach {
     
      # Get Send on Behalf Permissions
      $sendOnbehalfUsers = Get-SendOnBehalf -mailbox $_
      
      # Get Fullaccess Permissions
      $fullAccessUsers = Get-FullAccessPermissions -identity $_.UserPrincipalName

      Write-Host "Full Access Permissions:" -ForegroundColor Yellow
      Write-Host $fullAccessUsers

      # Get Send as Permissions
      $sendAsUsers = Get-SendAsPermissions -identity $_.UserPrincipalName

      Write-Host "SendAs Access Permissions:" -ForegroundColor Yellow
      Write-Host $sendAsUsers

      # Count number or records
      $sob = $sendOnbehalfUsers.Count
      $fa = $fullAccessUsers.Count
      $sa = $sendAsUsers.Count

      if ($folderPermissions.IsPresent) {
        
        # Get Inbox folder permission
        $inboxFolder = Get-FolderPermissions -identity $_.UserPrincipalName -folder $inboxFolderName
        $ib = $inboxFolder.users.Count

        # Get Calendar permissions
        $calendarFolder = Get-FolderPermissions -identity $_.UserPrincipalName -folder $calendarFolderName
        $ca = $calendarFolder.users.Count
      }else{
        $inboxFolder = @{
            users = @()
            permission = @()
            delegated = @()
        }
        $calendarFolder = @{
            users = @()
            permission = @()
            delegated = @()
        }
        $ib = 0
        $ca = 0
      }
     
      $mostRecords = Find-LargestValue -sob $sob -fa $fa -sa $sa -ib $ib -ca $ca

      Write-Host "Most records amount is $mostRecords" -ForegroundColor Yellow

      $x = 0
      if ($mostRecords -gt 0) {
          
          Do{
            if ($x -eq 0) {
                [pscustomobject]@{
                  "Display Name" = $_.DisplayName
                  "Emailaddress" = $_.PrimarySMTPAddress
                  "Mailbox type" = $_.RecipientTypeDetails
                  "Read and manage" = @($fullAccessUsers)[$x]
                  "Send as" = @($sendAsUsers)[$x]
                  "Send on behalf" = @($sendOnbehalfUsers)[$x]
                  "Inbox folder" = @($inboxFolder.users)[$x]
                  "Inbox folder Permission" = @($inboxFolder.permission)[$x]
                  "Inbox folder Delegated" = @($inboxFolder.delegated)[$x]
                  "Calendar" = @($calendarFolder.users)[$x]
                  "Calendar Permission" = @($calendarFolder.permission)[$x]
                  "Calendar Delegated" = @($calendarFolder.delegated)[$x]
                }
                $x++;
            }else{
                [pscustomobject]@{
                  "Display Name" = ''
                  "Emailaddress" = ''
                  "Mailbox type" = ''
                  "Read and manage" = @($fullAccessUsers)[$x]
                  "Send as" = @($sendAsUsers)[$x]
                  "Send on behalf" = @($sendOnbehalfUsers)[$x]
                  "Inbox folder" = @($inboxFolder.users)[$x]
                  "Inbox folder Permission" = @($inboxFolder.permission)[$x]
                  "Inbox folder Delegated" = @($inboxFolder.delegated)[$x]
                  "Calendar" = @($calendarFolder.users)[$x]
                  "Calendar Permission" = @($calendarFolder.permission)[$x]
                  "Calendar Delegated" = @($calendarFolder.delegated)[$x]
                }
                $x++;
            }

            $currentUser = $_.DisplayName
            if ($mailboxes.Count -gt 1) {
              Write-Progress -Activity "Collecting mailbox permissions" -Status "Current Count: $i" -PercentComplete (($i / $mailboxes.Count) * 100) -CurrentOperation "Processing mailbox: $currentUser"
            }
          }
          while($x -ne $mostRecords)
      }
      $i++;
    }
  }
}

Get-AllMailboxPermissions | Export-CSV -Path $path -NoTypeInformation

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green

  # Open the CSV file
  Invoke-Item $path

}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}