<#
.SYNOPSIS
  Get all AD Groups with properties and export to CSV
.DESCRIPTION
  This script collects all Active Directory groups with the most important properties. 
.OUTPUTS
  CSV
.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  01-09-2022
  Purpose/Change: Initial script development
.EXAMPLE
  Get all AD computers from the whole Domain

   .\Get-ADGroups.ps1 -csvpath c:\temp\computers.csv
.EXAMPLE
  Get enabled and disabled computers

   .\Get-ADGroups.ps1 -builtin include -csvpath c:\temp\computers.csv

   Other options are : true or false
.EXAMPLE
  Specify OU to look up into
  .\Get-ADGroups.ps1 -searchBase "OU=computers,OU=Amsterdam,DC=LazyAdmin,DC=Local" -csvpath c:\temp\computers.csv
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter the searchbase between quotes or multiple separated with a comma"
    )]
  [string[]]$searchBase,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Include built-in groups or exclude"
  )]
  [ValidateSet("include", "exclude")]
  [string]$builtin = "exclude",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$CSVpath
)

Function Get-Groups{
    <#
    .SYNOPSIS
      Get groups from the requested DN
    #>
    param(
      [Parameter(
        Mandatory = $true
      )]
      $dn
    )
    process{
      # Set the properties to retrieve
      $properties = @(
        'Name',
        'CanonicalName',
        'GroupCategory',
        'GroupScope',
        'ManagedBy',
        'MemberOf',
        'created',
        'whenChanged',
        'mail',
        'info',
        'description'
      )

      
      # Get all groups, or exclude the builtin groups
      # Get the computers
      switch ($builtin)
      {
        "include" {
          Get-ADGroup -filter * -searchBase $dn -Properties $properties | select $properties
        }
        "exclude" {
          $builtinUsers = "CN=users,$dn" 
          $filter = "GroupScope -ne 'Domainlocal'"
          Get-ADGroup -filter $filter -searchBase $dn -Properties $properties |  Where-Object { $_.DistinguishedName -notlike "*,$builtinUsers" } | select $properties
        }
      }
    }
}

Function Get-ADGroups {
  <#
    .SYNOPSIS
      Get all AD Groups
  #>
  process {
    Write-Host "Collecting groups" -ForegroundColor Cyan
    $groups = @()

    # Collect groups
    if ($searchBase) {
      # Get the requested groups
       foreach ($dn in $searchBase) {
         Write-Host "- Get groups in $dn" -ForegroundColor Cyan
         $groups += Get-Groups -dn $dn
       }
     }else{
       # Get distinguishedName of the domain
       $dn = Get-ADDomain | Select -ExpandProperty DistinguishedName
       Write-Host "- Get groups in $dn" -ForegroundColor Cyan
       $groups += Get-Groups -dn $dn
     }
 

    # Loop through all computers
    $groups | ForEach {
      $managedBy = ''
      $memberOf = ''

      # If the group is managed, get the users name
      if ($null -ne $_.ManagedBy) {
        $managedBy = Get-ADUser -Identity $_.ManagedBy | select -ExpandProperty name
      }

      # If the group is member of other groups, get the group names
      if ($_.MemberOf.count -gt 0) {
        $memberOf = Get-ADPrincipalGroupMembership $_.name | select -ExpandProperty name
      }

      [pscustomobject]@{
        "Name" = $_.Name
        "CanonicalName" = $_.CanonicalName
        "GroupCategory" = $_.GroupCategory
        "GroupScope" = $_.GroupScope
        "Mail" = $_.Mail
        "Description" = $_.Description
        "Info" = $_.info
        "ManagedBy" = $managedBy
        "MemberOf" = ($memberOf | out-string).Trim()
        "Date created" = $_.created
        "Date changed" = $_.whenChanged
      }
    }
  }
}

If ($CSVpath) {
  # Get mailbox status
  Get-ADGroups | Export-CSV -Path $CSVpath -NoTypeInformation -Encoding UTF8
  if ((Get-Item $CSVpath).Length -gt 0) {
      Write-Host "Report finished and saved in $CSVpath" -ForegroundColor Green
  } 
  else {
      Write-Host "Failed to create report" -ForegroundColor Red
  }
}
Else {
  Get-ADGroups
}