#requires -version 5
<#
.SYNOPSIS
  Module for staffOffBoarding script

.DESCRIPTION
  Contains multiple functions
 
.NOTES
  Version:        1.1
  Author:         R. Mens
  Creation Date:  2 Mrt 2017
  Last update:		01 feb 2021
	Changes:
		1.1	
		- Added EXO v2 module
		- Added check if EXO and Msol sessions exist

#>
#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Get the config file
$config = Get-Content $PSScriptRoot"\config.json" -Raw | ConvertFrom-Json

#Get the script location
$rootPath = (Get-Item $PSScriptRoot).FullName

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
$DebugPreference = 'Continue'

#Check if AD module is available
if ((Get-Module -ListAvailable -Name ActiveDirectory) -eq $null) 
{
	Write-Error "Please install RSAT Tools for your client."
}

#Import the sessions
if ((Get-Module -ListAvailable -Name ExchangeOnlineManagement) -ne $null) 
{
	# Check if there is a active EXO sessions
	$psSessions = Get-PSSession | Select-Object -Property State, Name
	If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
		Connect-ExchangeOnline -UserPrincipalName $config.settings.adminUserPrincipalName
	}
}
else{
	Write-Error "Please install EXO v2 module."
}

if ((Get-Module -ListAvailable -Name MSOnline) -ne $null) 
{
	# Check if we already have a connection to Msol
	if(-not (Get-MsolDomain -ErrorAction SilentlyContinue))
	{
		Connect-MsolService
	}
}else{
	Write-Error "Please install MSOL Services."
}


#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function Get-CurrentUser
{
	#region Get current user from AD
	Write-Verbose "Get current user for audit details"
	try 
	{
		$user = Get-ADUser $env:username -properties Mail, MemberOf
	}
	catch
	{
		Write-Host "Unable to find current loggedon user in AD $_"
		Exit
	}
	#endregion
	
	#region Check if current user if member of admin group
	
	$adminGroup = $config.Settings.Admingroup
	Write-Verbose "Check if user is member of $adminGroup"
	if ($user.MemberOf -like "CN=$adminGroup*")
	{
		return $user
	}
	else
	{
		Write-Host "$user.name is not a member of de admin group $adminGroup" -ForegroundColor Red
		Exit
	}
	#endregion
}

Function Get-UserDetails
{
	PARAM(
		[parameter(Mandatory=$true)]
		[string]$userPrincipalName
	)

	PROCESS
	{
		#region Get employee to remove from AD
		Write-Verbose "Check if employee exists in AD"
		try 
		{
			return Get-ADUser -filter {UserPrincipalName -eq $userPrincipalName} -properties * -ErrorAction Stop
		}
		catch 
		{ 
			Write-Host $_ -ForegroundColor Red -BackgroundColor Black
			return $null
		} 
		#endregion
	}
}

Function Get-Manager
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$false)]
		[string]$manager
	)

	PROCESS
	{
		#region Get manager of the employee
		Write-Debug "Get the manager of the user"
		if ($employee.Manager -eq $null)
		{
			Write-Debug "Manager not registerd in AD, check if manager is given"
			if (!$manager)
			{
				# No manager set and no manager registed in active directory.
				# Send email to the loggedon user so he can send it manually to the manager if nessary
				Write-Debug "No manager found, send email to loggedon user"
				Write-Warning 'Manager of user not found, unable to send email to manager. Email will be send to you instead'
				$manager = $env:username
			}
		}
		else
		{
			$manager = $employee.Manager
		}

		Write-Debug "Get the manager $manager details from AD"
		return Get-ADUser $manager -properties *
		#endregion
	}
}

Function Get-UserMailbox
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee
	)

	PROCESS{
		if ((Get-EXOMailbox -Identity $employee.mail -erroraction SilentlyContinue) -ne $null) 
		{
			return $true
		}
		else
		{
			return $false
		}
	}
}

Function Set-OutOfOfficeReply
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$false)]
		[bool]$whatIf

	)

	PROCESS
	{
		Try
		{
			#Get the current Out of Office state
			$AutoReplyConfiguration = Get-MailboxAutoReplyConfiguration -Identity $employee.mail | Select-Object AutoReplyState
			Write-Debug "AutoreplyState: $AutoReplyConfiguration"

			If ($AutoReplyConfiguration.AutoReplyState -eq 'Disabled')
			{
				#Replace placeholders with data
				$interalMessage = $config.Settings.internalOutOfOfficeMessage
				$externalMessage = $config.Settings.externalOutOfOfficeMessage `
				-replace '{{manager.fullname}}', $manager.name `
				-replace '{{manager.phone}}', $manager.OfficePhone `
				-replace '{{manager.mail}}', $manager.mail

				#Set the OutofOffice
				Write-Debug "OutOfOffice is disabled, setting outofOffice with default message"
				Set-MailboxAutoReplyConfiguration -Identity $employee.Mail -AutoReplyState enabled -ExternalAudience all `
				-InternalMessage $interalMessage `
				-ExternalMessage $externalMessage `
				-WhatIf:$whatIf
			}
			Else
			{
				Write-Debug "User already has OutOfOffice enabled"
			}
		}
		Catch
		{
			Write-host "Unable to get AutoReplyState for $employee.mail. Does the user have an mailbox?" -ForegroundColor Yellow
		}
	}
}

Function Set-MailboxToShared
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$true)]
		[bool]$grantAccess,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)

	PROCESS
	{
		#Check if mailbox is not to big to share
		$mailbox = Get-Mailbox -identity $employee.mail | Get-MailboxStatistics | Select TotalItemSize

		#Convert Mailbox Size to int
		$mbSize = [int]($mailbox.TotalItemSize -replace "(.*\()|,| [a-z]*\)", "")

		#If the mailbox is not to big, convert it to shared
		if ($mbSize -lt 49GB)
		{
			Set-Mailbox -Identity $employee.mail -Type Shared -Whatif:$whatif

			if ($grantAccess -eq $true)
			{
				Add-MailboxPermission -Identity $employee.mail -User $manager.mail -AccessRights readpermission -InheritanceType All
			}
		}
		else
		{
			Write-Error 'Unable to convert mailbox to shared. Mailbox is to big.'
		}
	}
}

Function Get-EmailTemplate
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$true)]
		$templateName,
		[parameter(Mandatory=$false)]
		$removedLicenses
	)

	PROCESS
	{
		#Get the mailtemplate
		$mailTemplate = (Get-Content ($rootPath + '\' + $config.Settings.$templateName)) | ForEach-Object {
			$_ 	-replace '{{manager.firstname}}', $manager.GivenName `
			-replace '{{user.fullname}}', $employee.Name `
			-replace '{{removedLicenses}}', $removedLicenses
		} | Out-String	
		return $mailTemplate
	}
}

Function Send-MailtoManager
{
	PARAM(
		[parameter(Mandatory=$true)]
		$emailBody,
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
	
    PROCESS
	{
		#Create subject of the email
		$subject = $config.SMTP.subject -replace '{{user.fullname}}', $employee.Name

		Try 
		{
			if ($whatIf -ne $true)
			{
				send-MailMessage -SmtpServer $config.SMTP.address -To $manager.mail -From $config.SMTP.from -Bcc $config.SMTP.bcc -Subject $subject -Body $emailBody -BodyAsHtml
			}
			else
			{
				Write-host ("Send mail to -SmtpServer " + $config.SMTP.address + " -To " + $manager.mail + " -From " + $config.SMTP.from + " -Subject $subject")
			}
		}
		Catch [System.Object]
		{
			Write-Error "Failed to send email to manager, $_"
		}
	}
}

Function Send-MailtoAdmin
{
	PARAM(
		[parameter(Mandatory=$true)]
		$emailBody,
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
	
    PROCESS
	{
		#Create subject of the email
		$subject = $config.SMTP.subject -replace '{{user.fullname}}', $employee.Name

		Try 
		{
			if ($whatIf -ne $true)
			{
				send-MailMessage -SmtpServer $config.SMTP.address -To $config.SMTP.adminEmail -From $config.SMTP.from -Subject $subject -Body $emailBody -BodyAsHtml
			}
			else
			{
				Write-host ("Send mail to -SmtpServer " + $config.SMTP.address + " -To " + $config.adminEmail + " -From " + $config.SMTP.from + " -Subject $subject")
			}
		}
		Catch [System.Object]
		{
			Write-Error "Failed to send email to manager, $_"
		}
	}
}


Function Remove-UserFromGroup
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$true)]
		$group,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)

	PROCESS
	{
		#Check if user is member of given group.
		if ((Get-ADUser $employee.SamAccountName -Properties memberof).memberof -like $group)
		{
			#Remove the user from the group
			Remove-ADGroupMember -Identity $group -Member $employee.SamAccountName -WhatIf:$whatIf
		}
	}
}

Function Remove-O365License
{
	PARAM(
		[parameter(Mandatory=$true)]
		$employee,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)

	PROCESS
	{

		#It can take a couple of seconds before the mailbox is changed to shared.
		#Removing the licens to early will result in deletion of the mailbox.
		Do
		{
			Write-Host '... Waiting until mailbox is changed to shared'
			Start-Sleep -s 15
			$mailboxType = Get-Mailbox -Identity $employee.mail | Select-Object RecipientTypeDetails
		}
		While ($mailboxType.RecipientTypeDetails -eq 'UserMailbox')
		
		#Check if user has an Office365 License
		$userLicenseDetails = Get-MsolUser -UserPrincipalName $employee.UserPrincipalName | Select-Object Licenses

		#Remove all the Office 365 licenses from this user
		if ($userLicenseDetails.Count -gt 0) {
			Foreach ($license in $userLicenseDetails)
			{
				$AccountSkuId = $license.Licenses.AccountSkuId
				if ($whatIf -ne $true)
				{
					#Remove license
					Set-MsolUserLicense -UserPrincipalName $employee.UserPrincipalName -RemoveLicenses $AccountSkuId
					return $AccountSkuId
				}
				else
				{
					Write-Host "Remove license $AccountSkuId"
				}
			}
		}
	}
}