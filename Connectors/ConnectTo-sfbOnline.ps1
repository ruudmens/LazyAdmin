<#
.SYNOPSIS
	Connect to Skype for Business Online. Optional save credentials for autonomous execution

.DESCRIPTION
	Connect to Skype for Business Online. You can store your credentials in the script root. When 
	saved the script will connect automaticaly. if no credentials are found it will ask for them.

.REQUIREMENTS
	Install the Microsoft Online Services Sign-In Assistant
	https://www.microsoft.com/en-us/download/details.aspx?id=41950

	Install the Skype for Business Online, Windows PowerShell Module
	https://www.microsoft.com/en-us/download/details.aspx?id=39366

.EXAMPLE
	Connecting to Skype for Business Online

	.\ConnectTo-sfbOnline.ps1

.EXAMPLE
	Save credentials in the script root

	.\ConnectTo-sfbOnline.ps1 -save
   
.NOTES
	Version:        1.3
	Author:         R. Mens
	Blog:			http://lazyadmin.nl
	Creation Date:  29 mrt 2017
	
.LINK
	https://github.com/ruudmens/SysAdminScripts/tree/master/Connectors
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------
[CmdletBinding()]
PARAM(	
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$save=$false
)
BEGIN
{
	$computerName = $env:COMPUTERNAME
	$uaPath = "$PSScriptRoot\useraccount-$computerName.txt"
	$ssPath = "$PSScriptRoot\securestring-$computerName.txt"
}
PROCESS
{
	#region save credentials
	If ($save)
	{
		#create securestring and store credentials
		Write-Host 'Running in config mode, storing credentials in script root location' -ForegroundColor Yellow
		$username = Read-Host "Enter your email address"	
		$secureStringPwd = Read-Host -assecurestring "Please enter your password"

		#Storing password as a securestring
		$secureStringText = $secureStringPwd | ConvertFrom-SecureString 
		Set-Content $ssPath $secureStringText

		#Storing username
		Set-Content $uaPath $username

		Write-Host 'Credentials saved' -ForegroundColor Green
	}
	#endregion

	Write-Host 'Connecting to Skype for Business Online' -ForegroundColor Yellow
	
	#Check if a securestring password is stored in the script root
	If (Test-Path $ssPath) 
	{
		$securePwd = Get-Content $ssPath | ConvertTo-SecureString
	}

	#Check if useraccount is stored in the script root
	If (Test-Path $uaPath)
	{
		$username = Get-Content $uaPath
	}

	#If the useraccount or password is empty, ask for the credentials
	if (!$securePwd -or !$username)
	{
		Write-Host 'No credentials stored. Run with -save option to store credentials' -ForegroundColor Yellow

		$username = Read-Host "Enter your email address"
		$securePwd = Read-Host -assecurestring "Please enter your password"
	}
		
	#Create credential object
	$credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

	#Import the Skype for Business Online PS session
	$sfbSession = New-CsOnlineSession -Credential $credObject
	Import-PSSession $sfbSession
	
}