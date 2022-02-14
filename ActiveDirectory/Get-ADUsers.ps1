<#
.SYNOPSIS
  Get all AD Users with properties and export to CSV

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
  Get enabled and disabled users

   .\Get-ADusers.ps1 -enabled both -path c:\temp\users.csv

   Other options are : true or false

.EXAMPLE
  Don't lookup the managers display name
  .\Get-ADusers.ps1 -getManager:$false -path c:\temp\users.csv

.EXAMPLE
  Specify OU to look up into
  .\Get-ADusers.ps1 -searchBase "OU=users,OU=Amsterdam,DC=LazyAdmin,DC=Local" -path c:\temp\users.csv
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Get the users manager"
  )]
  [switch]$getManager = $true,

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
  [string]$enabled = "true",

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
        'manager',
        'department',
        'telephoneNumber',
        'office',
        'mobile',
        'streetAddress',
        'city',
        'postalcode',
        'state',
        'country',
        'description',
        'lastlogondate'
      )

      # Get enabled, disabled or both users
      switch ($enabled)
      {
        "true" {$filter = "enabled -eq 'true'"}
        "false" {$filter = "enabled -eq 'false'"}
        "both" {$filter = "*"}
      }

      # Get the users
      Get-ADUser -Filter $filter -Properties $properties -SearchBase $dn | select $properties
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

    if ($searchBase) {
     # Get the requested mailboxes
      foreach ($dn in $searchBase) {
        Write-Host "- Get users in $dn" -ForegroundColor Cyan
        $users += Get-Users -dn $dn
      }
    }else{
      # Get distinguishedName of the domain
      $dn = Get-ADDomain | Select -ExpandProperty DistinguishedName
      Write-Host "- Get users in $dn" -ForegroundColor Cyan
      $users += Get-Users -dn $dn
    }

    $users | ForEach {

      $manager = ""

      If (($getManager.IsPresent) -and ($_.manager)) {
        # Get the users' manager
        $manager = Get-ADUser -Identity $_.manager | Select -ExpandProperty Name
      }

      [pscustomobject]@{
        "Name" = $_.Name
        "UserPrincipalName" = $_.UserPrincipalName
        "Emailaddress" = $_.mail
        "Job title" = $_.Title
        "Manager" = $manager
        "Department" = $_.Department
        "Office" = $_.Office
        "Phone" = $_.telephoneNumber
        "Mobile" = $_.mobile
        "Enabled" = if ($_.Enabled) {"enabled"} else {"disabled"}
        "Street" = $_.StreetAddress
        "City" = $_.City
        "Postal code" = $_.PostalCode
        "State" = $_.State
        "Country" = $_.Country
        "Description" = $_.Description
        "Last login" = $_.lastlogondate
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