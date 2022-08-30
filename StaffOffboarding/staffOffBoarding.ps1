<#
.SYNOPSIS
	Staff offboarding script. 

.DESCRIPTION
	This script handles staff that is leaving the company. It wil revoke all access to 
	IT systems and inform the manager of the user that the account is closed.

	The script does the following:

	1. Update the user description with who and when disabled account
	2. Disables the user account
	3. Check if the user had an emailbox, if so:
		3.1 Set the out-of-office reply if it's not set by the user self
		3.2 Disable all access to the mailbox
		3.3 Remove the user from the Global Access List
		3.4 Convert the mailbox to shared so we can revoke the license but leave the out-of-office active
	4. Remove users from specific AD groups
	5. Retract any office 365 licenses that is assigned to the user and sign the user out of all sessions
	6. Inform the manager, if set or given, about the account.
	7. Send mail to IT department

	#TODO
	NOTE: You could run a cleanup script that removes the account from your AD and SharedMailboxes after x days.

.PARAMETER <user> / <employee>
	The user account to remove

.PARAMETER <manager> (optional)
	You can give the manager to infom, if not set it will lookit up in the Active Directory.

.PARAMETER <sendMailConfirmation> / <mail> (default = true)
	Sends a email confirmation to the manager, if no manager found or given, you will receive the email.

.PARAMETER <setOutOfOffice> (default = true)
	Sets the Out of Office reply when its'n set by the user self.

.PARAMETER <grantManagerAccess> (default = false)
	Grants the manager access to the shared mailbox

.PARAMETER <Whatif> (default = false)
	Set to true to run the scrip in test mode.

.PARAMETER <confirm> (default = false)
	Set to true to confirm every step.

.PARAMETER <confirm> (default = false)
	Set to true to get confirmation before disabeling the user account.

.PARAMETER <keepEXOConnection> (default = false}
  Set to true if you want to keep the EXO connection open, for example when you run this based on an CSV file

.EXAMPLE
	Remove user John Doe	

	.\staffOffBoarding.ps1 -user johndoe

.EXAMPLE
	Remove user John Doe and grant the manager read access to the mailbox

	.\staffOffBoarding.ps1 -user johndoe -grantManagerAccess

.EXAMPLE
	Remove user John Doe and don't send email notification and don't set out of office reply

	.\staffOffBoarding.ps1 -user johndoe -sendMailConfirmation:$false -setOutOfOffice:$false

.EXAMPLE
	Run script in test mode to. This won't disable the user account or remove any licenses

	.\staffOffBoarding.ps1 -user johndoe -WhatIf

 .EXAMPLE
	  Import-Csv -Delimiter ";" -Path ("path\to\file\users-to-enable.csv") | Foreach-Object { staffOffBoarding -$userPrincipalName $_.UserPrincipalName -keepEXOConnection }

    Enable MFA for all users in a CSV file
   
.NOTES
	Version:        1.1
	Author:         R. Mens
	Blog:						http://lazyadmin.nl
	Creation Date:  02 mrt 2017
	Last update:		01 feb 2021
	Changes:
		1.1	
		- Added EXO v2 module
		- Removed need for O365.ps1 script
		- Change employee name to UserPrincipalName
		- Check if users exists before we continue anything
		- Added MFA support
		- Added Signout of user's sessions
		- Added check for active Msol and EXO sesions, preveting multiple connections

.LINK
	

#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------
[CmdletBinding()]
PARAM(	
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true,
				Position=0)]
	[string[]]$userPrincipalName,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[string]$manager,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[Alias('mail')]
	[switch]$sendMailConfirmation=$true,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$setOutOfOffice=$true,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$grantManagerAccess=$false,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$whatIf=$false,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$confirm=$false,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$keepEXOConnection=$false
)
BEGIN
{
	If ($PSBoundParameters['Debug']) {
		$DebugPreference = 'Continue'
	}

	#Import Staff Offboarding module
	Write-Debug "Import staffOffBoardingModule"
	Import-Module $PSScriptRoot\staffOffBoardingModule.psm1 -force
	
	#Get current user
	Write-Debug "Get currentuser $env:username with mail details"
	$user = Get-CurrentUser

	#Get date for audit details
	$disabledOnDate = Get-Date

	#Get config
	$config = Get-Content $PSScriptRoot"\config.json" -Raw | ConvertFrom-Json

	clear-host
}
PROCESS
{
	foreach ($user in $UserPrincipalName) {
		#region Get employee and manager details
		$employeeDetails = Get-UserDetails -userPrincipalName $user

		if ($employeeDetails -ne $null)  {
			Write-debug $employeeDetails

			$managerDetails = Get-Manager -Employee $employeeDetails -Manager $manager -Debug:$false
			Write-debug $managerDetails.mail
			#endregion

			#region 1. Set description for audit
			Set-ADUser $employeeDetails -Description "Disabled by $($user.name) on $disabledOnDate" -WhatIf:$whatIf
			Write-debug "Set user disabled description"
			#endregion

			#region 2. Disable the user account
			Disable-ADAccount -Identity $employeeDetails -Confirm:$confirm -WhatIf:$whatIf
			Write-debug "Disable user account"
			#endregion

			#region 3. Check if user has a mailbox
			if (Get-UserMailbox -employee $employeeDetails)
			{
				#region 3.1. Set out-of-office reply
				if ($setOutOfOffice) 
				{
					Set-OutOfOfficeReply -Employee $employeeDetails -Manager $managerDetails -WhatIf:$whatIf -Debug:$false
					Write-debug "Set out-of-office reply"
				}
				#endregion

				#region 3.2. Disable all client access to the mailbox
				Set-CasMailbox -Identity $employeeDetails.mail -OWAEnabled $false -POPEnabled $false -ImapEnabled $false -ActiveSyncEnabled $false -WhatIf:$whatIf
				Write-debug "Disable client access to mailbox"
				#endregion

				#region 3.3. Remove user from Global Access List 
				Set-ADUser -Identity $employeeDetails -Add @{msExchHideFromAddressLists=$true} -WhatIf:$whatIf
				Write-debug "Remove user from the GAL"
				#endregion

				#region 3.4. Convert user mailbox to shared
				Set-MailboxToShared -Employee $employeeDetails -Manager $managerDetails -GrantAccess $grantManagerAccess -WhatIf:$whatIf
				Write-debug "Convert mailbox to shared"
				#endregion
			}
			#endregion

			#region 4. Remove user from Remote Desktop Group
			Remove-UserFromGroup -Employee $employeeDetails -Group $config.settings.removeUserFromGroup -WhatIf:$whatIf
			Write-debug "Remove user from group"
			#endregion

			#region 5. Retract Office365 License and signout user
			$removedLicenses = Remove-O365License -Employee $employeeDetails -WhatIf:$whatIf
			Write-debug "Remove assigned licenses"

			Revoke-UserSessions -Employee $employeeDetails -WhatIf:$whatIf
			Write-debug "Close all users sessions"
			#endregion

			#region 6. Send notification email to manager
			if ($sendMailConfirmation) {
				$emailBody = Get-EmailTemplate -Employee $employeeDetails -Manager $managerDetails -TemplateName 'mailTemplateFile'

				Send-MailtoManager -EmailBody $emailBody -Employee $employeeDetails -Manager $managerDetails -WhatIf:$whatIf
				Write-debug "Send mail to manager"
			}
			#endregion

			#region 7. Send notification email to admin
			if ($sendMailConfirmation) {
				$emailBody = Get-EmailTemplate -Employee $employeeDetails -Manager $managerDetails -RemovedLicenses $removedLicenses -TemplateName 'mailTemplateFileAdmin'
				Send-MailtoAdmin -EmailBody $emailBody -Employee $employeeDetails -Manager $managerDetails  -WhatIf:$whatIf
				Write-debug "Send mail to admin"
			}
			#endregion

			[PSCustomObject]@{
				UserPrincipalName = $user
				UserDisabled      = $true
				MailSendTo        = $managerDetails.mail
				RemovedLicenses   = $removedLicenses
			}

		}else{
			write-warning "Unable to find user $user"
			[PSCustomObject]@{
				UserPrincipalName = $user
				UserDisabled      = $false
			}
		}
	}
}
END
{
	if ($keepEXOConnection -eq $false)
	{
		Disconnect-ExchangeOnline -config $false -WhatIf:$whatIf
	}
}