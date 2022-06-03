<#
.SYNOPSIS
  Bulk add users from a CSV file to a Azure AD group

.DESCRIPTION
  Import CSV file and add each user to a group.

.OUTPUTS
  none

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  03 june 2022
  Purpose/Change: Initial script development

.EXAMPLE
  Add users from CSV file to selected group

  .\add-azureaduserstogroup.ps1 -groupName "SG_PowerBi" -path c:\temp\users.csv -delimiter "," -filter "DisplayName"
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
    [ValidateSet("DisplayName", "mail", "UserPrincipalName")]
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
            $user = Get-AzureADUser -filter "$filter eq '$_'" | Select ObjectID 

            if ($user) {
                Add-AzureADGroupMember -ObjectId $group -RefObjectId $user
                Write-Host "$_ added to the group"
            }else {
                Write-Warning "$_ not found in Azure AD"
            }
        }
    }
}

Function Get-GroupId {
  <#
  .SYNOPSIS
    Find AzureAD Group
  #>
  process{
    $group = Get-AzureADGroup -Filter "displayname eq '$groupname'" | Select ObjectID
    if ($group.count -gt 1) {
      Write-Warning "Multiple groups with the name $groupname found"
      Write-host $group
      Write-Error "Specify exact groupname"
      exit
    }
  }
}

# Check if MS Graph module is installed
if (Get-InstalledModule AzureAD*) {
  # Connect to AzureAD
  Connect-AzureAD
}else{
  Write-Host "Microsoft AzureAD not found - please install it" -ForegroundColor Black -BackgroundColor Yellow
  exit
}

# Find group id
Get-GroupId $groupName

# Add user from CSV to given Group
Add-UsersToGroup