<#
.SYNOPSIS
  Create WireGuard configuration file for NordVPN
.DESCRIPTION
  Uses an existing NordVPN connection, NordVPN Access token and the WireGuard Client
  to create a WireGuard configuration file that be used in UniFi Network
.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  10 sep 2024
  Purpose/Change: Initial script development
#>

# Script needs to run in elevated mode
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Not running as Administrator. Please run as Admin." -ForegroundColor Red
    exit
}

# Check if WireGuard Client is installed 
# and if a VPN connection exists
function Test-WireGuard {
    do {
        try {
            $wgResult = & wg show NordLynx  2>&1
            
            if ($wgResult -like "*Unable to access interface*") {
                Write-Host "WireGuard Client installed, but VPN not connect" -ForegroundColor Yellow
                $ready = Read-Host "Press Enter once you have connected the VPN to continue..."
            }
            elseif ($LASTEXITCODE -eq 0) {
                Write-Host "WireGuard is installed and VPN connected" -ForegroundColor Green
                break
            }
        } catch {
            Write-Host "WireGuard Client is not installed."
            $ready = Read-Host "Press Enter once you have installed WireGuard to continue..."
        }
    } until ($LASTEXITCODE -eq 0)
}

# Step 1 - Install the NordVPN Client
#          Set the VPN type to NordLynx in the Settings > Connection
Write-Host "Make sure that you have the NordVPN client installed" -ForegroundColor Cyan

# Step 2 - Create an access token
# https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/

Write-Host "Open https://my.nordaccount.com/dashboard/nordvpn/manual-configuration/" -ForegroundColor Cyan
Write-Host "Create a new Access Token" -ForegroundColor Cyan

$accessToken = Read-Host -Prompt "Copy the Access Token from NordVPN"

# Step 3 - Install the WireGuard client
Write-Host "Make sure that you have installed the WireGuard Client" -ForegroundColor Cyan

# Step 4 - Connect the NordVPN Client
Write-Host "Connect your NordVPN Client to your desired server/location" -ForegroundColor Cyan

# Check if Wireguard is installed and VPN is connected
Test-WireGuard

# Step 5 - Get the Private Key 
Write-Host "Getting the Private key"
$privateKey = curl -s -u token:$accessToken "https://api.nordvpn.com/v1/users/services/credentials" | ConvertFrom-Json | Select-Object -ExpandProperty nordlynx_private_key

<# Alternative method for Step 5 
$token = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(“token:$accessToken”))
$headers = @{
Authorization = “Basic $token”
}

$response = Invoke-RestMethod -Uri “https://api.nordvpn.com/v1/users/services/credentials” -Headers $headers -Method Get
$privateKey = $response.nordlynx_private_key
#>

# Step 6 - Get the information for the configuration file
$listenPort = wg show NordLynx listen-port
$publicKey = wg show NordLynx public-key

$preSharedKey = (wg show NordLynx preshared-keys) -replace '\s+\(none\)$', '' -replace '\s+$', ''

$endPointRaw = wg show NordLynx endpoints
$ipRegex = [regex]'\b(?:\d{1,3}\.){3}\d{1,3}:\d{1,5}\b'
$endPoint = ($ipRegex.Match($endPointRaw)).Value

# Step 7 - Create the WireGuard Configuration file
$fileName = Read-Host "Enter a name for the configuration file"
$filePath = "c:\temp\$fileName.conf"

if (Test-Path -Path $filePath) {
    Write-Host "File already exists, it will be overwritten"
    Read-Host "Press Enter to continue..."
}
$filePath = New-Item -path $filePath -Force

$confFileContent = @"
[Interface]
ListenPort = $listenPort
PublicKey = $publicKey
PrivateKey =  $privateKey
Address = 10.5.0.2/32
DNS = 1.1.1.1

[Peer]
PublicKey = $preSharedKey
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $endPoint
PersistentKeepalive = 60
ForcedHandshake = 5
"@

Add-Content -path $filePath -Value $confFileContent

Write-Host "Script completed, configuration file saved in $($filePath.FullName)" -ForegroundColor Green