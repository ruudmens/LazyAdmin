# Not my script, source unknow, have to look it up
$global:authHeader = $null
$global:msgraphToken = $null
$global:tokenRequestedTime = [DateTime]::MinValue

$global:forceMSALRefreshIntervalMinutes = 30

function Get-MSCloudIdAccessToken {
    [CmdletBinding()]
    param (
        [string]
        $TenantId,
        [string]
        $ClientID,
        [string]
        $RedirectUri,
        [string]
        $Scopes,
        [switch]
        $Interactive
    )
    
    $msalToken = $null
	$connectionDetails = @{
		'TenantId'    = '5d1ab28c-185e-4bf0-83ec-00e1e5a59f72'
		'ClientId'    = 'ad622395-1477-4811-9d5c-448f98c0a9d7'
		'ClientSecret' = 'DP/C70JEzqdwFAnA28F/BMcQ+84aQPySUzZTH95t5rk=' | ConvertTo-SecureString -AsPlainText -Force
		'ForceRefresh'
	}
	
	$msalToken = Get-MsalToken @connectionDetails
	
    Write-Output $MsalToken
}

function Connect-MSGraphAPI {
    [CmdletBinding()]
    param (
        [string]
        $TenantId,
        [string]
        $ClientID = "1b730954-1685-4b74-9bfd-dac224a7b894",
        [string]
        $RedirectUri = "urn:ietf:wg:oauth:2.0:oob",
        [string]
        $Scopes = "https://graph.microsoft.com/.default",
        [switch]
        $Interactive
    )
	
	$graphConnectionDetails = @{
		'TenantId'    = '5d1ab28c-185e-4bf0-83ec-00e1e5a59f72'
		'ClientId'    = '1b730954-1685-4b74-9bfd-dac224a7b894'
		'RedirectUri' = 'urn:ietf:wg:oauth:2.0:oob'
		'Scopes' = 'https://graph.microsoft.com/.default'
		'Interactive' = $false
	}
	
	$token = Get-MsalToken @connectionDetails
    
    $Header = @{ }
    $Header.Authorization = "Bearer {0}" -f $token.AccessToken
    $Header.'Content-type' = "application/json"
    
    $global:msgraphToken = $token
    $global:authHeader = $Header
}

function Start-MSCloudIdSession        
{
    Connect-MSGraphAPI
    $msGraphToken = $global:msgraphToken
	
	$msolConnectionDetails = @{
		'TenantId'    = '5d1ab28c-185e-4bf0-83ec-00e1e5a59f72'
		'ClientId'    = '1b730954-1685-4b74-9bfd-dac224a7b894'
		'RedirectUri' = 'urn:ietf:wg:oauth:2.0:oob'
		'Scopes' = 'https://graph.microsoft.com/.default'
	}
	

    $aadTokenPsh = Get-MSCloudIdAccessToken -ClientID 1b730954-1685-4b74-9bfd-dac224a7b894 -Scopes "https://graph.windows.net/.default"  -RedirectUri "urn:ietf:wg:oauth:2.0:oob" 
	$aadTokenPsh = Get-MsalToken @msolConnectionDetails
    #$aadTokenPsh

    Connect-AzureAD -AadAccessToken $aadTokenPsh.AccessToken  -MsAccessToken $msGraphToken.AccessToken -AccountId $msGraphToken.Account.UserName -TenantId $msGraphToken.TenantID  | Out-Null
    Connect-MsolService -AdGraphAccesstoken $aadTokenPsh.AccessToken -MsGraphAccessToken $msGraphToken.AccessToken | Out-Null

    $global:tokenRequestedTime = [DateTime](Get-Date)

    Write-Debug "Session Established!"
}