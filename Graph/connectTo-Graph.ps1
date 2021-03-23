#requires -version 4
<#
.SYNOPSIS
  
.DESCRIPTION
  Connect to Azure Graph. Permission for Graph API are set on https://apps.dev.microsoft.com

.INPUTS
  config.json is required in the same folder

.OUTPUTS
  At the script location
	-refreshToken.txt with a 14 day vali refreshToken
	-accessToken.txt with a 1 hour valid accessToken
	-authCode.txt with a 1 hour valid authorizationCode

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  08 may 2017
  Purpose/Change: 
  
.EXAMPLE
  connectTo-Graph.ps1

#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

#Get the config file
$config = Get-Content $PSScriptRoot"\config.json" -Raw | ConvertFrom-Json

# Add System Web Assembly to encode ClientSecret
Add-Type -AssemblyName System.Web

# Encode ClientSecret
$clientSecretEncoded = [System.Web.HttpUtility]::UrlEncode($config.AppId.ClientSecret) 

# Get the accessToken
If ((Test-Path -Path $PSScriptRoot"\accessToken.txt") -ne $false) {
	$accessToken = Get-Content $PSScriptRoot"\accessToken.txt"
}

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Check if the AccessToken is not older then 1 hour
If (($accessToken -eq $null) -or ((get-date) - (get-item $PSScriptRoot"\accessToken.txt").LastWriteTime).TotalHours -gt 1) {

	# Get the refreshToken
	$refreshToken = Get-Content $PSScriptRoot"\refreshToken.txt"

	$clientId = $config.AppId.ClientId
	$clientSecret = $config.AppId.clientSecret
	$redirectUrl = $config.AppId.RedirectUrl
	$resourceUrl = $config.AppId.ResourceUrl
	
	Try {
		$refreshBody = "grant_type=refresh_token&redirect_uri=$redirectUrl&client_id=$clientId&client_secret=$clientSecretEncoded&refresh_token=$refreshToken&resource=$resourceUrl"

		$Authorization = Invoke-RestMethod https://login.microsoftonline.com/common/oauth2/token `
			-Method Post -ContentType "application/x-www-form-urlencoded" `
			-Body $refreshBody `
			-UseBasicParsing
	}
	Catch {
		$webResponse = $_.Exception.Response
	}

	If ($webResponse -ne $null) {
		# Get Authorization code
		GraphAPIGetAuthCode.ps1 -ClientId $clientId -ClientSecret $clientSecret -RedirectUrl $redirectUrl   

		$authCode = get-content $PSScriptRoot"\authCode.txt"
		$body = "grant_type=authorization_code&redirect_uri=$redirectUrl&client_id=$clientId&client_secret=$clientSecretEncoded&code=$authCode&resource=$resourceUrl"

		$Authorization = Invoke-RestMethod https://login.microsoftonline.com/common/oauth2/token `
			-Method Post -ContentType "application/x-www-form-urlencoded" `
			-Body $body `
			-UseBasicParsing
	}

	# Store refreshToken
	Set-Content $PSScriptRoot"\refreshToken.txt" $Authorization.refresh_token

	# Store accessToken
	$accessToken = $Authorization.access_token
	Set-Content $PSScriptRoot"\accessToken.txt" $accessToken
} 
