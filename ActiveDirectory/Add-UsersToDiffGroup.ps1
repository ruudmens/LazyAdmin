<#
.SYNOPSIS
  Bulk add users from a CSV file to different Active Directory groups

.DESCRIPTION
  Import CSV file and add each user to the specified group.

.OUTPUTS
  none

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  22 march 2022
  Purpose/Change: Initial script development

.EXAMPLE
  Add users from CSV file to selected group

  .\Add-UsersToDiffGroup.ps1 -path c:\temp\users.csv -delimiter "," -filter "DisplayName"
#>

[CmdletBinding()]
param (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "Path to CSV file"
    )]
    [string] $Path = "",

    [Parameter(
      Mandatory = $false,
      HelpMessage = "CSV file delimiter"
    )]
    [string] $Delimiter = ",",

    [Parameter(
      Mandatory = $false,
      HelpMessage = "Find users on DisplayName, Email or UserPrincipalName"
    )]
    [ValidateSet("DisplayName", "Email", "UserPrincipalName")]
    [string] $Filter = "DisplayName"
)

Function Add-UserToGroup {
    <#
    .SYNOPSIS
      Get users from the requested DN
    #>
    process{
      # Import the CSV File
      $users = Import-Csv -Path $path -Delimiter $delimiter

      # Find the users in the Active Directory
      $users | ForEach {
          $user = Get-ADUser -filter "$filter -eq '$($_.user)'" | Select ObjectGUID 

          if ($user) {
              Add-ADGroupMember -Identity $_.Group -Members $user
              Write-Host "$($_.user) added to $($_.Group)"
          }else {
              Write-Warning "$($_.user) not found in the Active Directory"
          }
      }
  }
}

# Load the Active Directory Module
Import-Module -Name ActiveDirectory

# Add user from CSV to given Group
Add-UserToGroup