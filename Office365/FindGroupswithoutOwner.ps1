<#
.SYNOPSIS
  Find Microsoft 365 Groups without Owner
.DESCRIPTION
  Find all groups in Microsoft 365 that don't have an owner. Optional set a default owner for the group. If the group has multiple members then 
  you can select one of the members as owner.
.EXAMPLE
  FindGroupswithoutOwner.ps1 -adminUPN admin@contoso.com -setOwner:$true -fallbackOwner admin@contoso.com 
  Find all groups without owner and set the owner. If the group doesn't have any member, use admin@contoso.com as fallback owner.
.EXAMPLE
  FindGroupswithoutOwner.ps1 -adminUPN admin@contoso.com -setOwner:$false
  List only all groups with owner

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  6 mrt 2023
  Purpose/Change: Init
  Link:           
#>
param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter the Exchange Online or Global admin username"
  )]
  [string]$adminUPN,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Set owner of groups without owner"
  )]
  [switch]$setOwner = $false,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Fallback owner for groups without owner"
  )]
  [string]$fallbackOwner
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

    if ((Get-Module -ListAvailable -Name ExchangeOnlineManagement) -ne $null) 
    {
	    # Check if there is a active EXO sessions
	    $psSessions = Get-PSSession | Select-Object -Property State, Name
	    If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
        Write-Host "Connecting to Exchange Onlie" -ForegroundColor Cyan
		    Connect-ExchangeOnline -UserPrincipalName $adminUPN -ShowBanner:$false
	    }
    }
    else{
      Write-Error "Please install EXO v3 module."
    }
  }
}

Function Get-GroupswithoutOwner {
  # Get all groups without Owner
  $groups = Get-UnifiedGroup | Where-Object {-Not $_.ManagedBy}

  if ($setOwner) {
    # Get all members for each group
    $groups | ForEach-Object {

    # Check if the groups has members
    $groupMembers = Get-UnifiedGroupLinks -Identity $_ -LinkType Members
   
    
    # Set Member as Owner of Group
      if ($groupMembers.count -ne 0) {
        Set-MemberasOwner -group $_ -groupMembers $groupMembers
      }else{
        # Group doesn't have any members, setting fallback user as owner (first need to make it a member)
        Write-Host "Setting $fallbackOwner as owner for $($_.displayName)" -ForegroundColor Green
        Add-UnifiedGroupLinks -Identity $_ -LinkType Members -Links $fallbackOwner
        Add-UnifiedGroupLinks -Identity $_ -LinkType Owners -Links $fallbackOwner
      }
    }
  }else{
    # Just return all groups without any owners
    $groups
  }
}

Function Set-MemberasOwner {
  PARAM(
    [parameter(Mandatory=$true)]
    $group,

    [parameter(Mandatory=$true)]
    $groupMembers
  )
  Process {
    if (($groupMembers | Measure-Object).Count -eq 1) {
      # Make the only member of the group owner
      Write-Host "Setting $($groupMembers[0].Name) as owner for $($group.displayName)" -ForegroundColor Green
      $owner = $groupMembers[0]
    }else{
      # List all members of the group and let the user choose one of them as owner
      Do {
        Write-Host "Select one of the members as owner for $($group.DisplayName)" -ForegroundColor Yellow

        $index = 1
        $groupMembers | ForEach-Object {
            Write-Host "[$index] $($_.name)"
            $index++
        }
    
        $selection = Read-Host 
      } Until ($groupMembers[$selection-1])

      Write-Host "You selected $($groupMembers[$selection-1].name)...." -ForegroundColor Cyan
      $owner = $groupMembers[$selection-1]
    }

    # Set the owner of the group
    Add-UnifiedGroupLinks -Identity $group -LinkType Owners -Links $owner
  }
}

# Connect to Exchange Online
ConnectTo-EXO

# Get all Microsoft 365 Groups without Owner
Get-GroupswithoutOwner