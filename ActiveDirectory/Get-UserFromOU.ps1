<#
.SYNOPSIS
  Get all AD Users and their email address from specific OU and export to CSV

.DESCRIPTION
  This script collects all Active Directory users with the most important properties. By default it will only
  get the enabled users, manager of the user and searches the whole domain.

.OUTPUTS
  CSV with Active Direct

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  12 feb 2022
  Purpose/Change: Initial script development

.EXAMPLE
  Get all AD users from the whole Domain

   .\Get-ADusers.ps1 -path c:\temp\users.csv

.EXAMPLE
  Specify OU to look up into
  .\Get-ADusers.ps1 -searchBase "OU=users,OU=Amsterdam,DC=LazyAdmin,DC=Local" -path c:\temp\users.csv
#>

param(
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter the searchbase between quotes or multiple separated with a comma"
        )]
        [string]$searchBase,
    
    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter path to save the CSV file"
    )]
    [string]$path = ".\ADUsers-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function Get-Users {
    <#
    .SYNOPSIS
      Get users from the requested DN
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
        'name',
        'userprincipalname',
        'mail',
        'title',
        'telephoneNumber',
        'mobile',
        'department',
        'extensionAttribute5',
        'extensionAttribute3',
        'extensionAttribute4'
      )

      # Get the user
      Get-ADUser -Filter "Enabled -eq 'true'" -searchBase $dn -properties $properties | where {$_.extensionAttribute5 -eq 'ListInDigitalReception'} | select $properties
    }
}


Function Get-AllADUsers {
    <#
      .SYNOPSIS
        Get all AD users
    #>
    process {
      Write-Host "Collecting users" -ForegroundColor Cyan
      $users = @()
  
      # Collect users
      $users += Get-Users -dn $searchBase
  
      # Loop through all users
      $users | ForEach {
  
        [pscustomobject]@{
          "Name" = $_.Name
          "UserPrincipalName" = $_.UserPrincipalName
          "Emailaddress" = $_.mail
          "Phone" = $_.telephoneNumber
          "Mobile" = $_.mobile
          "Job title" = $_.Title
          "Department" = $_.Department
          "Extension3" = $_.extensionAttribute3
          "Extension4" = $_.extensionAttribute4
        }
      }
    }
  }
  

Get-AllADUsers | Sort-Object Name | Export-CSV -Path $path -NoTypeInformation

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green

  # Open the CSV file
  Invoke-Item $path

}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}