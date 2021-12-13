<#
.SYNOPSIS
  Update user's jobtitle in Active Directory

.DESCRIPTION
  Update jobtitles based on a CSV with usernames and new jobtitle

.EXAMPLE
  Set-UserPromotions.ps1 -csvPath c:\temp\promotions.csv

.NOTES
  Version:        1.1
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  jan 2019
  Purpose/Change: CSV from command line.
  Link:           https://lazyadmin.nl/powershell/using-powershell-to-update-an-ad-user-from-a-csv-file/
#>

param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter the path inc filename of the CSV file"
  )]
  [string]$csvPath,

	[parameter(
		ValueFromPipeline=$true,
		ValueFromPipelineByPropertyName=$true,
		Mandatory=$false
	)]
	[switch]$whatIf = $false
)

#
# Configuration
#

# Set the SMTP details to send out the notification mail
$smtp = @{
	"address" = "stonegrovebank.mail.protection.outlook.com"
	"from" = "IT Dept <it@stonegrovebank.com>"
	"subject" = "Jobtitle updated."
}

#Get the script location
$rootPath = (Get-Item $PSScriptRoot).FullName

Function Get-EmailTemplate {
  <#
    .SYNOPSIS
    Get the eamil template which is located in the same location as the script
  #>
	PARAM(
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$jobtitle
	)

	PROCESS
	{
		#Get the mailtemplate
		$mailTemplate = (Get-Content ($rootPath + '\MailTemplate.html')) | ForEach-Object {
			$_ 	-replace '{{user.jobtitle}}', $jobtitle`
			-replace '{{user.firstname}}', $user.givenName
		} | Out-String	
		
		return $mailTemplate
	}
}

Function Send-Mail {
	<#
    .SYNOPSIS
    Send the user a mail.
  #>
	PARAM(
		[parameter(Mandatory=$true)]
		$emailBody,
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
	
    PROCESS
	{
		#Set encoding
		$encoding = [System.Text.Encoding]::UTF8

		Try 
		{
			if ($whatIf -ne $true)
			{
				send-MailMessage -SmtpServer $smtp.address -To $user.mail -From $smtp.from -Subject $smtp.subject -Encoding $encoding -Body $emailBody -BodyAsHtml
			}
			else
			{
				Write-host ("Send mail to -SmtpServer " + $smtp.address + " -To " + $user.mail + " -From " + $smtp.from + " -Subject $smtp.subject")
			}
		}
		Catch
		{
			Write-Error "Failed to send email to, $_"
		}

	}
}

# Run the script
$promotions = Import-Csv -Delimiter ";" -Path $csvPath

foreach($user in $promotions){
    #find user
    $ADUser = Get-ADUser -Filter "displayname -eq '$($user.user)'" -Properties mail

    if ($ADUser){
        Set-ADUser -Identity $ADUser -Title $user.jobtitle

        $emailBody = Get-EmailTemplate -user $ADUser -JobTitle $user.jobtitle
        Send-Mail -user $ADUser -EmailBody $emailBody -whatIf $whatIf
    }else{
        Write-Warning ("Failed to update " + $($user.user))
    }
}