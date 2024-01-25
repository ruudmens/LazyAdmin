<#
.SYNOPSIS
  Get all AD members from an AD Group
.DESCRIPTION
  This script collects all Active Directory users from a specific group or multiple groups and exports
  the users with some attributes to a CSV file per AD Group.
.OUTPUTS
  CSV or console with Active Directory Users
.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  25 jan 2024
  Purpose/Change: Init
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter the group name or multiple separated with a comma"
    )]
  [string[]]$groupName,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter the searchbase between quotes or multiple separated with a comma"
    )]
  [string[]]$searchBase,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Get accounts that are enabled, disabled or both"
  )]
    [ValidateSet("true", "false", "both")]
  [string]$enabled = "both",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$CSVpath
)

Function Get-Users{
  param(
    [Parameter(Mandatory = $true)]
    $dn
  )
  # Set the properties to retrieve
  $properties = @(
    'name',
    'userprincipalname',
    'mail',
    'title',
    'enabled',
    'department',
    'lastlogondate'
  )

  # Get enabled, disabled or both users
  switch ($enabled) {
    "true" {$filter = "enabled -eq 'true' -and"}
    "false" {$filter = "enabled -eq 'false' -and"}
    "both" {$filter = ""}
  }

  # Return the users from the group
  Get-ADUser -Filter "$filter memberOf -recursivematch '$($dn)'" -Properties $properties | Select-Object $properties
}

Function Get-CSVFile {
  # Creates the CSV File per group with the group members
  param(
    [Parameter(Mandatory = $true)]
    $group,

    [Parameter(Mandatory = $true)]
    $users
  )

  # Create CSV File path with Groupname and datetime
  $CSVFilePath = $CSVPath + "\" + $group + "-" + (Get-Date -Format "yyMMdd-hhmm") + ".csv"
  
  # Export users to CSV File per Group
  $users | Sort-Object Name | Export-CSV -Path $CSVFilePath -NoTypeInformation -Encoding UTF8

  if ((Get-Item $CSVFilePath).Length -gt 0) {
    Write-Host "- Report finished and saved in $CSVFilePath" -ForegroundColor Green
  } else {
    Write-Host "- Failed to create report" -ForegroundColor Red
  }
}

Function Get-GroupMembers {
  # Get the group members from the specified group
  # and export the results to CSV or console
  param(
    [Parameter(Mandatory = $true)]
    $group
  )
  
  Write-Host "- Getting users for $($group.name)" -ForegroundColor Cyan
  $users = Get-Users -dn $group.distinguishedName

  if ($null -eq $users){
    Write-Host "- No users found in $($group.name)" -ForegroundColor Yellow
    return
  }

  If ($CSVpath) {
    Get-CSVFile -group $group.name -users $users
  } else {
    $users | Sort-Object Name | ft
  }
}

Function Get-Groups {
  # Get the groups, either from the parameter,
  # or lookup all the groups in specified OU
  if ($groupName) {
    foreach ($group in $groupName) {
      Write-Host "- Getting group details for $group" -ForegroundColor Cyan
      $ADGroup = Get-ADGroup -Identity $group
    
      if ($null -eq $ADGroup) {
        Write-host "- Group $group not found" -ForegroundColor Red
        continue
      }
      Get-GroupMembers -group $ADGroup
    }
  }
  elseif ($searchBase) {
    # Get the requested users
    foreach ($dn in $searchBase) {
      Write-Host "- Collecting groups in $dn" -ForegroundColor Cyan
      Get-ADGroup -Filter * -SearchBase $dn | ForEach-Object { Get-GroupMembers -group $_ }
    }
  }
  else{
    # Get distinguishedName of the domain
    $dn = Get-ADDomain | Select-Object -ExpandProperty DistinguishedName
    Write-Host "- Collecting all groups in $dn" -ForegroundColor Cyan
    Get-ADGroup -Filter * -SearchBase $dn | ForEach-Object { Get-GroupMembers -group $_ }
  }
}

# Collect the group members
Get-Groups