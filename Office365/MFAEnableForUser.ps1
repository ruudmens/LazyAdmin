Function Set-MFAforUser {
<#
  .Synopsis
    Enables MFA for an Office 365 User

  .DESCRIPTION
    Enable MFA for an user, you can turn it on for a single user or input a list of users

  .NOTES
    Name: Set-MFAforUser
    Author: R. Mens - LazyAdmin.nl
    Version: 1.0
    DateCreated: jan 2021
    Purpose/Change: Initial script development

  .LINK
    https://lazyadmin.nl

  .EXAMPLE
    Set-MFAforUser -UserPrincipalName johndoe@contoso.com

    Enable MFA for the user John Doe

  .EXAMPLE
	  Import-Csv -Delimiter ";" -Path ("path\to\file\users-to-enable.csv") | Foreach-Object { Set-MFAforUser $_.UserPrincipalName }

    Enable MFA for all users in a CSV file
#>
 [CmdletBinding(DefaultParameterSetName="Default")]
  param(
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ParameterSetName  = "UserPrincipalName",
      Position = 0
      )]
    # Enter a single UserPrincipalName or a comma separted list of UserPrincipalNames
    [string[]]$UserPrincipalName
	)

Begin {}

Process {
	if ($PSBoundParameters.ContainsKey('UserPrincipalName')) {
		foreach ($user in $UserPrincipalName) {
			try {
		    # Src: https://docs.microsoft.com/en-us/azure/active-directory/authentication/howto-mfa-userstates
		    $sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
		    $sa.RelyingParty = "*"
		    $sa.State = "Enabled"
		    $sar = @($sa)

		    # Change the following UserPrincipalName to the user you wish to change state
		    Set-MsolUser -UserPrincipalName $user -StrongAuthenticationRequirements $sar -ErrorAction Stop

		    [PSCustomObject]@{
			    UserPrincipalName = $user
			    MFAEnabled        = $true
		    }
	    }
	    catch {
		    [PSCustomObject]@{
			    UserPrincipalName = $user
			    MFAEnabled        = $false
		    }
	    }
	 }
	}else{
		Write-Verbose "No UserPrincipalName given"
	}
  }
}