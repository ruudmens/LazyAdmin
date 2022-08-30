# Not my script. Source unknown, have to look it up..

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
      'TenantId'    = $TenantId
      'ClientId'    = $ClientID
      'Interactive' = $true
      'RedirectUri' = $RedirectUri
      'Scopes'      = $Scopes
   }

    $MsalToken = get-msaltoken $connectionDetails              

    Write-Output $MsalToken
}


function Connect-MSGraphAPI {
    [CmdletBinding()]
    param (
        [string]
        $TenantId = '5d1ab28c-185e-4bf0-83ec-00e1e5a59f72',
        [string]
        $ClientID = "1b730954-1685-4b74-9bfd-dac224a7b894",
        [string]
        $RedirectUri = "urn:ietf:wg:oauth:2.0:oob",
        [string]
        $Scopes = "https://graph.microsoft.com/.default",
        [switch]
        $Interactive
    )
    
    $token = Get-MSCloudIdAccessToken -TenantId $TenantId -ClientID $ClientID -RedirectUri $RedirectUri -Scopes $Scopes -Interactive:$Interactive
    $Header = @{ }
    $Header.Authorization = "Bearer {0}" -f $token.AccessToken
    $Header.'Content-type' = "application/json"
    
    $global:msgraphToken = $token
    $global:authHeader = $Header
}

<#
 .Synopsis
  Starts the sessions to AzureAD and MSOnline Powershell Modules
 
 .Description
  This function prompts for authentication against azure AD
 
#>
function Start-MSCloudIdSession        
{
    Connect-MSGraphAPI
    $msGraphToken = $global:msgraphToken

    $aadTokenPsh = Get-MSCloudIdAccessToken -ClientID 1b730954-1685-4b74-9bfd-dac224a7b894 -Scopes "https://graph.windows.net/.default"  -RedirectUri "urn:ietf:wg:oauth:2.0:oob" 
    #$aadTokenPsh

    Connect-AzureAD -AadAccessToken $aadTokenPsh.AccessToken  -MsAccessToken $msGraphToken.AccessToken -AccountId $msGraphToken.Account.UserName -TenantId $msGraphToken.TenantID  | Out-Null
    Connect-MsolService -AdGraphAccesstoken $aadTokenPsh.AccessToken -MsGraphAccessToken $msGraphToken.AccessToken | Out-Null

    $global:tokenRequestedTime = [DateTime](Get-Date)

    Write-Debug "Session Established!"
}

Connect-MSGraphAPI