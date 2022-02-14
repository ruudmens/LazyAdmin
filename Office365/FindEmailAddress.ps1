<#
.SYNOPSIS
  Find email address in Office 365

.DESCRIPTION
  Search trough your mailboxes, distributions groups and Office 365 groups for an Email Addresses or part 
  of an email address.

.OUTPUTS
  List of recipient with mail addresses

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  14 feb 2022
  Purpose/Change: Initial script development

.EXAMPLE
  Seach for a specific email address

  .\FindEmailAddress.ps1 -adminUPN admin@contoso.com -emailaddress john@contoso.com

.EXAMPLE
  Search for all email addresses with john in it.

  .\FindEmailAddress.ps1 -adminUPN admin@contoso.com -emailaddress john

.EXAMPLE
  Export results to CSV
  
  .\FindEmailAddress.ps1 -adminUPN admin@contoso.com -emailaddress john | Export-CSV c:\temp\results.csv -NoTypeInformation
#>

param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter the Exchange Online or Global admin username"
  )]
  [string]$adminUPN,

  [Parameter(
    Mandatory = $true,
    HelpMessage = "Emailaddress or part of it to find"
  )]
  [string]$emailAddress
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

Function Search-Mailboxes {
  <#
  .SYNOPSIS
    Search for email address in the mailboxes
  #>
  process {
    Write-Host "Searching in mailboxes for $emailAddress" -ForegroundColor Cyan
    Get-EXOMailbox -filter "EmailAddresses -like '*$emailAddress*'"
  }
}

Function Search-Distributionlists {
  <#
  .SYNOPSIS
    Search for email address in the distributionlists
  #>
  process {
    Write-Host "Searching in distributionlists for $emailAddress" -ForegroundColor Cyan
    Get-DistributionGroup -Filter "EmailAddresses -like '*$emailAddress*'"
  }
}

Function Search-Groups {
  <#
  .SYNOPSIS
    Search for email address in the mailboxes
  #>
  process {
    Write-Host "Searching in groups for $emailAddress" -ForegroundColor Cyan
    Get-UnifiedGroup -Filter "EmailAddresses -like '*$emailAddress*'"
  }
}

Function Find-EmailAddress{
  <#
    .SYNOPSIS
      Get all AD users
  #>
  process {
    $result = @()

    $result += Search-Mailboxes
    $result += Search-Distributionlists
    $result += Search-Groups

    $result | ForEach {
        [pscustomobject]@{
          "DisplayName" = $_.DisplayName
          "RecipientType" = $_.RecipientType
          "Identity" = $_.identity
          "EmailAddresses" = $_.EmailAddresses
        }
    }
  }
}

# Connect to Exchange Online
ConnectTo-EXO

Find-EmailAddress | Sort-Object DisplayName 