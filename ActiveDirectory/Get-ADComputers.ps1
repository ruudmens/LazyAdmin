<#
.SYNOPSIS
  Get all AD Computers with properties and export to CSV

.DESCRIPTION
  This script collects all Active Directory computers with the most important properties. By default it will only
  get the enabled computers, manager of the user and searches the whole domain.

.OUTPUTS
  CSV with Active Direct

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  24 may 2022
  Purpose/Change: Initial script development

.EXAMPLE
  Get all AD computers from the whole Domain

   .\Get-ADComputers.ps1 -path c:\temp\computers.csv

.EXAMPLE
  Get enabled and disabled computers

   .\Get-ADComputers.ps1 -enabled both -path c:\temp\computers.csv

   Other options are : true or false

.EXAMPLE
  Specify OU to look up into
  .\Get-ADComputers.ps1 -searchBase "OU=computers,OU=Amsterdam,DC=LazyAdmin,DC=Local" -path c:\temp\computers.csv
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter the searchbase between quotes or multiple separated with a comma"
    )]
  [string[]]$searchBase,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Get computers that are enabled, disabled or both"
  )]
    [ValidateSet("true", "false", "both")]
  [string]$enabled = "true",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\ADcomputers-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function Get-Computers {
    <#
    .SYNOPSIS
      Get computers from the requested DN
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
        'OperatingSystem',
        'OperatingSystemVersion',
        'LastLogonDate',
        'LogonCount',
        'BadLogonCount',
        'IPv4Address',
        'Enabled',
        'whenCreated'
      )

      # Get enabled, disabled or both computers
      switch ($enabled)
      {
        "true" {$filter = "enabled -eq 'true'"}
        "false" {$filter = "enabled -eq 'false'"}
        "both" {$filter = ""}
      }

      # Get the computers
      Get-ADComputer -Filter $filter -searchBase $dn -Properties $properties | select $properties
    }
}


Function Get-AllADComputers {
  <#
    .SYNOPSIS
      Get all AD computers
  #>
  process {
    Write-Host "Collecting computers" -ForegroundColor Cyan
    $computers = @()

    # Collect computers
    if ($searchBase) {
      # Get the requested mailboxes
       foreach ($dn in $searchBase) {
         Write-Host "- Get computers in $dn" -ForegroundColor Cyan
         $computers += Get-Computers -dn $dn
       }
     }else{
       # Get distinguishedName of the domain
       $dn = Get-ADDomain | Select -ExpandProperty DistinguishedName
       Write-Host "- Get computers in $dn" -ForegroundColor Cyan
       $computers += Get-Computers -dn $dn
     }
 

    # Loop through all computers
    $computers | ForEach {

      [pscustomobject]@{
        "Name" = $_.Name
        "CanonicalName" = $_.CanonicalName
        "OS" = $_.OperatingSystem
        "OS Version" = $_.OperatingSystemVersion
        "Last Logon" = $_.lastLogonDate
        "Logon Count" = $_.logonCount
        "Bad Logon Count" = $_.BadLogonCount
        "IP Address" = $_.IPv4Address
        "Mobile" = $_.mobile
        "Enabled" = if ($_.Enabled) {"enabled"} else {"disabled"}
        "Date created" = $_.whenCreated
      }
    }
  }
}

Get-AllADComputers | Sort-Object Name | Export-CSV -Path $path -NoTypeInformation

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green

  # Open the CSV file
  Invoke-Item $path

}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}