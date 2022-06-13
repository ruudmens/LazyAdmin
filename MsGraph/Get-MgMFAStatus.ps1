<#
.Synopsis
  Get the MFA status for all users or a single user.

.DESCRIPTION
  This script will get the Azure MFA Status for your users. You can query all the users, admins only or a single user.
   
	It will return the MFA Status, MFA type and registered devices.

  Note: Default MFA device is currently not supported https://docs.microsoft.com/en-us/graph/api/resources/authenticationmethods-overview?view=graph-rest-beta
        Hardwaretoken is not yet supported

.NOTES
  Name: Get-MFAStatus
  Author: R. Mens - LazyAdmin.nl
  Version: 1.0
  DateCreated: Jun 2022
  Purpose/Change: Init

.LINK
  https://lazyadmin.nl

.EXAMPLE
  Get-MgMFAStatus

  Get the MFA Status of all enabled and licensed users and check if there are an admin or not

.EXAMPLE
  Get-MgMFAStatus -UserPrincipalName 'johndoe@contoso.com','janedoe@contoso.com'

  Get the MFA Status for the users John Doe and Jane Doe

.EXAMPLE
  Get-MgMFAStatus -withOutMFAOnly

  Get only the licensed and enabled users that don't have MFA enabled

.EXAMPLE
  Get-MgMFAStatus -adminsOnly

  Get the MFA Status of the admins only

.EXAMPLE
  Get-MsolUser -Country "NL" | ForEach-Object { Get-MFAStatus -UserPrincipalName $_.UserPrincipalName }

  Get the MFA status for all users in the Country The Netherlands. You can use a similar approach to run this
  for a department only.

.EXAMPLE
  Get-MgMFAStatus -withOutMFAOnly | Export-CSV c:\temp\userwithoutmfa.csv -noTypeInformation

  Get all users without MFA and export them to a CSV file
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
    ParameterSetName  = "AllUsers"
  )]
  # Set the Max results to return
  [int]$MaxResults = 10000,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false,
    ParameterSetName  = "Licensed"
  )]
  # Check only the MFA status of users that have license
  [switch]$IsLicensed = $true,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true,
    ParameterSetName  = "withOutMFAOnly"
  )]
  # Get only the users that don't have MFA enabled
  [switch]$withOutMFAOnly = $false,

  [Parameter(
    Mandatory         = $false,
    ValueFromPipeline = $false
  )]
  # Check if a user is an admin. Set to $false to skip the check
  [switch]$listAdmins = $true,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\MFAStatus-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function Get-Admins{
    <#
  .SYNOPSIS
    Get all user with an Admin role
  #>
  process{
    $admins = Get-MgDirectoryRole | Select-Object DisplayName, Id | 
                %{$role = $_.displayName; Get-MgDirectoryRoleMember -DirectoryRoleId $_.id | 
                  where {$_.AdditionalProperties."@odata.type" -eq "#microsoft.graph.user"} | 
                  % {Get-MgUser -userid $_.id | Where-Object {($_.AssignedLicenses).count -gt 0}}
                } | 
                Select @{Name="Role"; Expression = {$role}}, DisplayName, UserPrincipalName, Mail, ObjectId | Sort-Object -Property Mail -Unique
    
    return $admins
  }
}

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
  Connect-MgGraph -Scopes "User.Read.All, UserAuthenticationMethod.Read.All"

  # Select the beta profile
  Select-MgProfile Beta
}

Function Get-Users {
  <#
  .SYNOPSIS
    Get users from the requested DN
  #>
  process{
    # Set the properties to retrieve
    $properties = @(
      'id',
      'DisplayName',
      'userprincipalname',
      'mail'
    )

    # Get enabled, disabled or both users
    switch ($enabled)
    {
      "true" {$filter = "AccountEnabled eq true and UserType eq 'member'"}
      "false" {$filter = "AccountEnabled eq false and UserType eq 'member'"}
      "both" {$filter = "UserType eq 'member'"}
    }

    # Get the users
    #Get-MgUser -Filter $filter -Property $properties -All -ExpandProperty Manager | select $select
    Get-MgUser -userid "rudymens@thunnissen.nl" -Property $properties | select $select
  }
}

Function Get-MFAMethods {
  <#
    .SYNOPSIS
      Get the MFA status of the user
  #>
  param(
    [Parameter(Mandatory = $true)] $userId
  )
  process{
    # Get MFA details for each user
    [array]$mfaData = Get-MgUserAuthenticationMethod -UserId $userId

    # Create MFA details object
    $mfaMethods  = [PSCustomObject][Ordered]@{
      status            = "-"
      authApp           = "-"
      phoneAuth         = "-"
      fido              = "-"
      helloForBusiness  = "-"
      emailAuth         = "-"
      tempPass          = "-"
      passwordLess      = "-"
      softwareAuth      = "-"
      authDevice        = "-"
      authPhoneNr       = "-"
    }

    ForEach ($method in $mfaData) {
        Switch ($method.AdditionalProperties["@odata.type"]) {
          "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"  { 
            # Microsoft Authenticator App
            $mfaMethods.authApp = $true
            $mfaMethods.authDevice = $method.AdditionalProperties["displayName"] 
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.phoneAuthenticationMethod"                  { 
            # Phone authentication
            $mfaMethods.phoneAuth = $true
            $mfaMethods.authPhoneNr = $method.AdditionalProperties["phoneType", "phoneNumber"] -join ' '
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.fido2AuthenticationMethod"                   { 
            # FIDO2 key
            $mfaMethods.fido = $true
            $fifoDetails = $method.AdditionalProperties["model"]
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.passwordAuthenticationMethod"                { 
            # Password
            # When only the password is set, then MFA is disabled.
            if ($mfaMethods.status -ne "enabled") {$mfaMethods.status = "disabled"}
          }
          "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" { 
            # Windows Hello
            $mfaMethods.helloForBusiness = $true
            $helloForBusinessDetails = $method.AdditionalProperties["displayName"]
            $mfaMethods.status = "enabled"
          } 
          "#microsoft.graph.emailAuthenticationMethod"                   { 
            # Email Authentication
            $mfaMethods.emailAuth =  $true
            $emailAuthDetails = $method.AdditionalProperties["emailAddress"] 
            $mfaMethods.status = "enabled"
          }               
          "microsoft.graph.temporaryAccessPassAuthenticationMethod"    { 
            # Temporary Access pass
            $mfaMethods.tempPass = $true
            $tempPassDetails = $method.AdditionalProperties["lifetimeInMinutes"]
            $mfaMethods.status = "enabled"
          }
          "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" { 
            # Passwordless
            $mfaMethods.passwordLess = $true
            $passwordLessDetails = $MfaMethod.AdditionalProperties["displayName"]
            $mfaMethods.status = "enabled"
          }
          "#microsoft.graph.softwareOathAuthenticationMethod" { 
            # ThirdPartyAuthenticator
            $mfaMethods.softwareAuth = $true
            $mfaMethods.status = "enabled"
          }
        }
    }
    Return $mfaMethods
  }
}

Function Get-MFAStatusUsers {
  <#
    .SYNOPSIS
      Get all AD users
  #>
  process {
    Write-Host "Collecting users" -ForegroundColor Cyan
    
    # Collect and loop through all users
    Get-Users | ForEach {
      $mfaMethods = Get-MFAMethods -userId $_.id

      [pscustomobject]@{
        "Display Name" = $_.DisplayName
        Emailaddress = $_.mail
        UserPrincipalName = $_.UserPrincipalName
        isAdmin = if ($listAdmins -and ($admins.UserPrincipalName -match $_.UserPrincipalName)) {$true} else {"-"}
        "MFA Status" = $mfaMethods.status
      # "MFA Default type" = ""  - Not yet supported by MgGraph
        "Phone Authentication" = $mfaMethods.phoneAuth
        "Authenticator App" = $mfaMethods.authApp
        "Passwordless" = $mfaMethods.passwordLess
        "Hello for Business" = $mfaMethods.helloForBusiness
        "FIDO2 Security Key" = $mfaMethods.fido
        "Temporary Access Pass" = $mfaMethods.tempPass
        "Authenticator device" = $mfaMethods.authDevice
        "Phone number" = $mfaMethods.authPhoneNr
        "Email for SSPR" = $mfaMethods.emailAuth
      }
    }
  }
}

# Connect to Graph
ConnectTo-MgGraph

# Get Admins
# Get all users with admin role
$admin = $null

if (($listAdmins) -or ($adminsOnly)) {
  $admins = Get-Admins
} 

# Get MFA Status
Get-MFAStatusUsers | Sort-Object Name | Export-CSV -Path $path -NoTypeInformation

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green

  # Open the CSV file
  Invoke-Item $path
}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}
