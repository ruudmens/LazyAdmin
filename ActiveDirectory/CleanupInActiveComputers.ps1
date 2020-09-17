<#
.SYNOPSIS
  
.DESCRIPTION
  You can run this script in 2 modus, list the computers that will be disabled and disable the actual computers accounts.
  This allows you to get a notification one week before the computer accounts actual will be disabled. To prevent disableing
  of the computer account you can simply add the words "on hold" in de AD description field.

  The scripts comes with 2 email templates, one for the notification mail and one for that will be send when the computer accounts are disabled

  The script will NOT ask for confirmation. If you don't set -Whatif $true it will disable the accounts.

.OUTPUTS
  Email with disabled computer accounts

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  16 march 2017
  Purpose/Change: Initial script development

.EXAMPLE
  Send notification with computer accounts that will be disabled within 7 days, when they are 90 days inactive.

   .\CleanupInActiveComputers.ps1 -TimeSpan 90 -SearchBase "OU=Computers,DC=Contoso,DC=Local" -Notify

   this will list all computer accounts that are inactive for 83 days (90 - 7). So you can run that actual disableing script one week later 

.EXAMPLE
  Disable computers accounts that are inactive for 90 days

   .\CleanupInActiveComputers.ps1 -TimeSpan 90 -SearchBase "OU=Computers,DC=Contoso,DC=Local"

.EXAMPLE
  Run in test mode

   .\CleanupInActiveComputers.ps1 -TimeSpan 90 -SearchBase "OU=Computers,DC=Contoso,DC=Local" -WhatIf
#>


#----------------------------------------------------------[Declarations]----------------------------------------------------------
[CmdletBinding()]
PARAM(	
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true)]
	[Alias('days')]
	[string]$TimeSpan,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[string]$SearchBase,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$SendMail=$true,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$Notify=$false,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$whatIf=$false
)

BEGIN
{
	#Set mail details
	$SMTP = @{} 
	$SMTP.Address = "SMTP.DOMAIN.COM"
	$SMTP.From = "Servicedesk <Servicedesk@domain.com>"
	$SMTP.To = "someone@domain.com"
	$SMTP.NotificationTemplate = "MailTemplateDisabledComputersNotification.html"
	$SMTP.RemovedAccountsTemplate = "MailTemplateRemovedAccounts.html"
}
#-----------------------------------------------------------[Script]------------------------------------------------------------
PROCESS
{
	#Send notification one week before with computer accounts that are going to be disabled
	if ($Notify)
	{
		#Set timespan - 7 days so we can send the notification one week before the actual removal of the accounts
		$TimeSpan = ($TimeSpan - 7)

		#Get the computers accounts that will be deleted within x days that are not on hold
		$Computers = Search-ADAccount -AccountInactive -TimeSpan "$TimeSpan" -ComputersOnly -SearchBase $SearchBase | `
		Get-ADComputer -Properties description,lastlogondate | `
		Where-Object { $_.Description -notlike '*on hold*' } | `
		Select name,lastlogondate
		
		#Are there computers that will be disabled?
		if ($Computers.Length -gt 0) 
		{
			#Convert results to HTML Table
			$Table = $Computers | ConvertTo-Html -Fragment

			#Create the mail template
			$SMTP.Subject = "Listed Computers objects will be disabled in 7 days"

			$mailTemplate = (Get-Content ($PSScriptRoot + '\' + $SMTP.NotificationTemplate)) | ForEach-Object {
				$_ 	-replace '{{amount}}', $Accounts.Length `
				-replace '{{Table}}', $Table `
				-replace '{{TimeSpan}}', $TimeSpan `
			} | Out-String	

			#Send notification mail
			send-MailMessage -SmtpServer $SMTP.address -To $SMTP.To-From $SMTP.From -Subject $SMTP.Subject -Body $mailTemplate -BodyAsHtml -Priority High
		}
	}
	else
	{
		#Get the computers account to disable, we get them first so we can send an email with the disabled accounts
		$Computers = Search-ADAccount -AccountInactive -TimeSpan "$TimeSpan" -ComputersOnly -SearchBase $SearchBase | `
		Get-ADComputer -Properties description,lastlogondate | `
		Where-Object { $_.Description -notlike '*on hold*'} | `
		Select Name,lastlogondate
		
		#Are there computers that will be disabled?
		if ($Computers.Length -gt 0)
		{
			Foreach ($computer in $Computers)
			{
				#Disable the computer account
				Disable-ADAccount -Identity $Computer.DistinguishedName -Confirm:$false -WhatIf:$whatIf
			}

			#Convert results to HTML Table
			$Table = $Accounts | ConvertTo-Html -Fragment

			#Create the mail template
			if ($whatIf)
			{
				$SMTP.Subject = "[DEMOMODUS] Computer accounts disabled"
			}
			else
			{
				$SMTP.Subject = "Computer accounts disabled"
			}
			
			$mailTemplate = (Get-Content ($PSScriptRoot + '\' + $SMTP.DisabledComputersTemplate)) | ForEach-Object {
				$_ 	-replace '{{amount}}', $Computers.Length `
				-replace '{{Table}}', $Table `
			} | Out-String	

			#Send notification mail
			send-MailMessage -SmtpServer $SMTP.address -To $SMTP.To-From $SMTP.From -Subject $SMTP.Subject -Body $mailTemplate -BodyAsHtml
		}
	}
}