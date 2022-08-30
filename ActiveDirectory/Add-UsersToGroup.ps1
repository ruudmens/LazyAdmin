<#
.SYNOPSIS
  Bulk add users from a CSV file to a Active Directory group

.DESCRIPTION
  Import CSV file and add each user to a group.

.OUTPUTS
  none

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  22 march 2022
  Purpose/Change: Initial script development

.EXAMPLE
  Add users from CSV file to selected group

  .\add-userstogroups.ps1 -groupName "SG_PowerBi" -path c:\temp\users.csv -delimiter "," -filter "DisplayName"
#>

[CmdletBinding()]
param (
    [Parameter(
      Mandatory = $true,
      HelpMessage = "Group name"
    )]
    [string] $GroupName = "",

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

Function Add-UsersToGroup {
    <#
    .SYNOPSIS
      Get users from the requested DN
    #>
    process{
        # Import the CSV File
        $users = (Import-Csv -Path $path -Delimiter $delimiter -header "name").name

        # Find the users in the Active Directory
        $users | ForEach {
            $user =  Get-ADUser -filter "$filter -eq '$_'" | Select ObjectGUID 

            if ($user) {
                Add-ADGroupMember -Identity $groupName -Members $user
                Write-Host "$_ added to the group"
            }else {
                Write-Warning "$_ not found in the Active Directory"
            }
        }
    }
}

# Load the Active Directory Module
Import-Module -Name ActiveDirectory

# Add user from CSV to given Group
Add-UsersToGroup