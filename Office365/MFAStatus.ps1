<#
.Synopsis
  Get the MFA status for all users or a single user.

.DESCRIPTION
  This script will get the Azure MFA Status for your users. You can query all the users, admins only or a single user.
   
	It will return the MFA Status, MFA type (

.NOTES
  Name: Get-MFAStatus
  Author: R. Mens - LazyAdmin.nl
  Version: 1.1
  DateCreated: jan 2021
  Purpose/Change: Initial script development
	Thanks to: Anthony Bartolo

.LINK
  https://lazyadmin.nl

.EXAMPLE
  Get-MFAStatus

  Get the MFA Status of all enabled and licensed users and check if there are an admin or not

.EXAMPLE
  Get-MFAStatus -UserPrincipalName 'johndoe@contoso.com','janedoe@contoso.com'

  Get the MFA Status for the users John Doe and Jane Doe

.EXAMPLE
  Get-MFAStatus -withOutMFAOnly

  Get only the licensed and enabled users that don't have MFA enabled

.EXAMPLE
  Get-MFAStatus -adminsOnly

  Get the MFA Status of the admins only

.EXAMPLE
  Get-MsolUser -Country "NL" | ForEach-Object { Get-MFAStatus -UserPrincipalName $_.UserPrincipalName }

  Get the MFA status for all users in the Country The Netherlands. You can use a similar approach to run this
  for a department only.

.EXAMPLE
  Get-MFAStatus -withOutMFAOnly | Export-CSV c:\temp\userwithoutmfa.csv -noTypeInformation

  Get all users without MFA and export them to a CSV file
#>
[CmdletBinding(DefaultParameterSetName="Default")]
param(
  [Parameter(
    Mandatory = $false,
    ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName  = "UserPrincipalName",
    Position = 0
    )]
  # Enter a single UserPrincipalName or a comma separted list of UserPrincipalNames
  [string[]]$UserPrincipalName,

  [Parameter(
    Mandatory = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "AdminsOnly",
    Position = 0
  )]
  # Get only the users that are an admin
  [switch]$adminsOnly = $false,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "AllUsers"
  )]
  # Set the Max results to return
  [int]$MaxResults = 1000,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "AllUsers"
  )]
  # Check only the MFA status of users that have license
  [switch]$IsLicensed = $true,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName  = "AllUsers"
  )]
  # Get only the users that don't have MFA enabled
  [switch]$withOutMFAOnly = $false,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false
  )]
  # Check if a user is an admin. Set to $false to skip the check
  [switch]$listAdmins = $true
)

Begin {
  # Get all licensed admins
  $admins = $null

  if (($listAdmins) -or ($adminsOnly)) {
    $admins = Get-MsolRoleMember -RoleObjectId $(Get-MsolRole -RoleName "Company Administrator").ObjectId | Where-Object {$_.isLicensed -eq $true} | Select-Object ObjectId,EmailAddress
  }
}

Process {
# Check if a UserPrincipalName is given
# Get the MFA status for the given user(s) if they exist
if ($PSBoundParameters.ContainsKey('UserPrincipalName')) {
  foreach ($user in $UserPrincipalName) {
		try {
      $MsolUser = Get-MsolUser -UserPrincipalName $user -ErrorAction Stop

      $Method = ""
      $MFAMethod = $MsolUser.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq $true} | Select-Object -ExpandProperty MethodType

      If (($MsolUser.StrongAuthenticationRequirements) -or ($MsolUser.StrongAuthenticationMethods)) {
        Switch ($MFAMethod) {
            "OneWaySMS" { $Method = "SMS token" }
            "TwoWayVoiceMobile" { $Method = "Phone call verification" }
            "PhoneAppOTP" { $Method = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $Method = "Authenticator app" }
        }
      }

      [PSCustomObject]@{
        DisplayName       = $MsolUser.DisplayName
        UserPrincipalName = $MsolUser.UserPrincipalName
        isAdmin           = if ($listAdmins -and $admins.EmailAddress -match $MsolUser.UserPrincipalName) {$true} else {"-"}
        MFAEnabled        = if ($MsolUser.StrongAuthenticationMethods) {$true} else {$false}
        MFAType           = $Method
				MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
      }
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
}
# Get only the admins and check their MFA Status
elseif ($adminsOnly) {
  foreach ($admin in $admins) {
    $MsolUser = Get-MsolUser -ObjectId $admin.ObjectId | Sort-Object UserPrincipalName -ErrorAction Stop

    $MFAMethod = $MsolUser.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq $true} | Select-Object -ExpandProperty MethodType
    $Method = ""

    If (($MsolUser.StrongAuthenticationRequirements) -or ($MsolUser.StrongAuthenticationMethods)) {
        Switch ($MFAMethod) {
            "OneWaySMS" { $Method = "SMS token" }
            "TwoWayVoiceMobile" { $Method = "Phone call verification" }
            "PhoneAppOTP" { $Method = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $Method = "Authenticator app" }
        }
      }

    [PSCustomObject]@{
      DisplayName       = $MsolUser.DisplayName
      UserPrincipalName = $MsolUser.UserPrincipalName
      isAdmin           = $true
      MFAEnabled        = if ($MsolUser.StrongAuthenticationMethods) {$true} else {$false}
      MFAType           = $Method
			MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
    }
  }
}
# Get the MFA status from all the users
else {
  $MsolUsers = Get-MsolUser -EnabledFilter EnabledOnly -MaxResults $MaxResults | Where-Object {$_.IsLicensed -eq $isLicensed} | Sort-Object UserPrincipalName
    foreach ($MsolUser in $MsolUsers) {

      $MFAMethod = $MsolUser.StrongAuthenticationMethods | Where-Object {$_.IsDefault -eq $true} | Select-Object -ExpandProperty MethodType
      $Method = ""

      If (($MsolUser.StrongAuthenticationRequirements) -or ($MsolUser.StrongAuthenticationMethods)) {
        Switch ($MFAMethod) {
            "OneWaySMS" { $Method = "SMS token" }
            "TwoWayVoiceMobile" { $Method = "Phone call verification" }
            "PhoneAppOTP" { $Method = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $Method = "Authenticator app" }
        }
      }

      if ($withOutMFAOnly) {
        # List only the user that don't have MFA enabled
        if (-not($MsolUser.StrongAuthenticationMethods)) {

          [PSCustomObject]@{
            DisplayName       = $MsolUser.DisplayName
            UserPrincipalName = $MsolUser.UserPrincipalName
            isAdmin           = if ($listAdmins -and $admins.EmailAddress -match $MsolUser.UserPrincipalName) {$true} else {"-"}
            MFAEnabled        = $false
            MFAType           = "-"
						MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
          }
        }
      }else{
        [PSCustomObject]@{
          DisplayName       = $MsolUser.DisplayName
          UserPrincipalName = $MsolUser.UserPrincipalName
          isAdmin           = if ($listAdmins -and $admins.EmailAddress -match $MsolUser.UserPrincipalName) {$true} else {"-"}
          MFAEnabled        = if ($MsolUser.StrongAuthenticationMethods) {$true} else {$false}
          MFAType           = $Method
					MFAEnforced       = if ($MsolUser.StrongAuthenticationRequirements) {$true} else {"-"}
        }
      }
    }
  }
}