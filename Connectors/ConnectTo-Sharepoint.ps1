<#
.SYNOPSIS
	Connect to Sharepoint with PnP Powershell

.DESCRIPTION
	Connect to Sharepoint Online with PnP. More info here https://github.com/SharePoint/PnP-PowerShell

.REQUIREMENTS
	Install-Module SharePointPnPPowerShellOnline

.EXAMPLE
	Connecting to Skype for Business Online

	.\ConnectTo-Sharepoint.ps1 -site https://contoso.sharepoint.com/teams/zzzTestProject

.EXAMPLE
	Save credentials in the script root

	.\ConnectTo-Sharepoint.ps1 -save
   
.NOTES
	Version:        1.0
	Author:         R. Mens
	Blog:			http://lazyadmin.nl
	Creation Date:  02 may 2017
	
.LINK
	
#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------
[CmdletBinding()]
PARAM(	
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$config=$false,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[string]$siteUrl
)
BEGIN
{
	$computerName = $env:COMPUTERNAME
	$uaPath = "$PSScriptRoot\useraccount-$computerName.txt"
	$ssPath = "$PSScriptRoot\securestring-$computerName.txt"
}
PROCESS
{
	If ($config)
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
	}
	Else
	{
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
			$username = Read-Host "Enter your email address"
			$securePwd = Read-Host -assecurestring "Please enter your password"
		}
		
		#Create credential object
		$credObject = New-Object System.Management.Automation.PSCredential -ArgumentList $username, $securePwd

		#Import the Skype for Business Online PS session
		Connect-PnPOnline -url $siteUrl -Credentials $credObject
	}	
}