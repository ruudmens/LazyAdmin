<#
.Synopsis
  Get the MFA status for all users, admin or selected users from Microsoft Entra

.DESCRIPTION
  This script will get the Azure MFA Status for your users. You can query all the users, admins only or a single user.
   
	It will return the MFA Status, MFA type, Default method, SSRP, and registered devices.

.NOTES
  Name: Get-MgEntraMFAStatus
  Author: R. Mens - LazyAdmin.nl
  Version: 1.1
  DateCreated: Feb 2024
  Purpose/Change: Remove the beta cmdlet

.LINK
  https://lazyadmin.nl
#>
 
[CmdletBinding(DefaultParameterSetName="Default")]
param(
  [Parameter(
    Mandatory = $false,
    ParameterSetName  = "UserPrincipalName",
    HelpMessage = "Enter a single UserPrincipalName or a comma separted list of UserPrincipalNames",
    Position = 0
    )]
  [string[]]$UserPrincipalName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "AdminsOnly"
  )]
  # Get only the users that are an admin
  [switch]$adminsOnly = $false,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "Licensed"
  )]
  # Check only the MFA status of users that have license
  [switch]$IsLicensed = $true,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "Enabled"
  )]
  # Get enabled, disabled or both
  [string]$enabled = 'both',

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName  = "withOutMFAOnly"
  )]
  # Get only the users that don't have MFA enabled
  [switch]$withOutMFAOnly = $false,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$CSVPath = ".\EntraMFAStatus-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function ConnectTo-MgGraph {
  # Check if MS Graph module is installed
  if (-not(Get-InstalledModule Microsoft.Graph)) { 
    Write-Host "Microsoft Graph module not found" -ForegroundColor Black -BackgroundColor Yellow
    $install = Read-Host "Do you want to install the Microsoft Graph Module?"

    if ($install -match "[yY]") {
      Install-Module Microsoft.Graph -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
    }else{
      Write-Host "Microsoft Graph module is required." -ForegroundColor Black -BackgroundColor Yellow
      exit
    } 
  }

  # Connect to Graph
  Write-Host "Connecting to Microsoft Graph" -ForegroundColor Cyan
  Connect-MgGraph -Scopes "Reports.Read.All" -NoWelcome
}


Function Get-Admins{
  <#
  .SYNOPSIS
    Get all user with an Admin role
  #>
  process{
    $admins = Get-MgDirectoryRole | Select-Object DisplayName, Id | 
                %{$role = $_.DisplayName; Get-MgDirectoryRoleMember -DirectoryRoleId $_.id | 
                  where {$_.AdditionalProperties."@odata.type" -eq "#microsoft.graph.user"} | 
                  % {Get-MgUser -userid $_.id }
                } | 
                Select @{Name="Role"; Expression = {$role}}, DisplayName, UserPrincipalName, Mail, Id | Sort-Object -Property Mail -Unique
    
    return $admins
  }
}

Function Get-Users {
  # Set the properties to retrieve
  $select = @(
    'mail'
    'userprincipalname'
    'displayname'
  )

  $properties = $select + "AssignedLicenses"

  # Get enabled, disabled or both users
  switch ($enabled)
  {
    "true" {$filter = "AccountEnabled eq true and UserType eq 'member'"}
    "false" {$filter = "AccountEnabled eq false and UserType eq 'member'"}
    "both" {$filter = "UserType eq 'member'"}
  }
  
  # Check if UserPrincipalName(s) are given
  if ($UserPrincipalName) {
    Write-host "Get specific users" -ForegroundColor Cyan

    $users = @()
    foreach ($user in $UserPrincipalName) 
    {
      try {
        $users += Get-MgUser -UserId $user -Property $properties | select $select -ErrorAction Stop
      }
      catch {
        [PSCustomObject]@{
          DisplayName       = " - Not found"
          UserPrincipalName = $User
          isAdmin           = $null
          MFAEnabled        = $null
        }
      }
    }
  }elseif($adminsOnly)
  {
    Write-host "Get admins only" -ForegroundColor Cyan

    $users = @()
    foreach ($admin in $admins) {
      $users += Get-MgUser -UserId $admin.UserPrincipalName -Property $properties | select $select
    }
  }else
  {
    if ($IsLicensed) {
      # Get only licensed users
      $users = Get-MgUser -Filter $filter -Property $properties -all | Where-Object {($_.AssignedLicenses).count -gt 0} | select $select
    }else{
      $users = Get-MgUser -Filter $filter -Property $properties -all | select $select
    }
  }
  return $users
}

Function Get-Manager {
  <#
    .SYNOPSIS
      Get the manager users
  #>
  param(
    [Parameter(Mandatory = $true)] $userId
  )
  process {
    $manager = Get-MgUser -UserId $userId -ExpandProperty manager | Select @{Name = 'name'; Expression = {$_.Manager.AdditionalProperties.displayName}}
    return $manager.name
  }
}

Function Get-MFAStatusUsers {
  <#
    .SYNOPSIS
      Get all AD users
  #>
  process {
    Write-Host "Collecting users" -ForegroundColor Cyan
    
    # Collect users to get
    $users = Get-Users
    
    # Get all MFA Report data
    $reportData = Get-MgReportAuthenticationMethodUserRegistrationDetail

    Write-Host "Processing" $users.count "users" -ForegroundColor Cyan

    # Collect and loop through all users
    foreach ($reportUser in $reportData) {

      # Check if we want this users in the output
      # Note - it's faster to get all report data and then filter it on the selected users, 
      # then getting the report data for each individual user
      if ($reportUser.UserPrincipalName -notin $users.UserPrincipalName) {
        continue
      }

      Write-Host "- Processing $($reportUser.UserDisplayName)" -ForegroundColor Cyan

      # Get the user data from the users array
      $userData = $users | where-object {$_.UserPrincipalName -eq $reportUser.UserPrincipalName}

      # Get the manager of the user (optional)
      $manager = Get-Manager -userId $reportUser.id
      
      # Create output object
      [pscustomobject]@{
        "Name" = $userData.DisplayName
        "Emailaddress" = $userData.mail
        "UserPrincipalName" = $reportUser.UserPrincipalName
        "User Type" = $reportUser.UserType
        "isAdmin" = $reportUser.IsAdmin
        "MFA Capable" = $reportUser.IsMfaCapable
        "MFA Default method" = $reportUser.DefaultMfaMethod
        "MFA Secondary method" = $reportUser.UserPreferredMethodForSecondaryAuthentication
        "MFA Methods Registered" = $reportUser.MethodsRegistered -join ", "
        "Passwordless Capable" = $reportUser.IsPasswordlessCapable
        "SSPR Registered" = $reportUser.IsSsprRegistered
        "SSPR Capable" = $reportUser.IsSsprCapable
        "Manager" = $manager
      }
    }
  }
}

# Connect to Graph
ConnectTo-MgGraph

# Get Admins
# Get all users with admin role
$admins = $null

if ($adminsOnly) {
  $admins = Get-Admins
} 

# Get MFA Status
Get-MFAStatusUsers | Sort-Object Name | Export-CSV -Path $CSVPath -NoTypeInformation

if ((Get-Item $CSVPath).Length -gt 0) {
  Write-Host "Report finished and saved in $CSVPath" -ForegroundColor Green

  # Open the CSV file
  Invoke-Item $CSVPath
}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}