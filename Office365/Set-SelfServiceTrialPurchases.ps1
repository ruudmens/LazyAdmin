<#
.SYNOPSIS
  Disable Self-service trials and purchases in Microsoft 365
.DESCRIPTION
  Easily set all products to Do not allow or Trial only
.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  8 oct 2024
  Purpose/Change: Initial script development
#>
[CmdletBinding(DefaultParameterSetName="Default")]
param(
    [Parameter(
        Mandatory         = $true,
        ValueFromPipeline = $true
    )]
    [Alias("selfServiceSetting")]
    [ValidateSet("enabled","disabled", "OnlyTrialsWithoutPaymentMethod")]
    # Set the self service setting
    [string]$selfServiceSetting = 'disabled'
)

Function ConnectTo-MSCommerce {
    # Check if MS Graph module is installed
    if (-not(Get-InstalledModule MSCommerce)) { 
      Write-Host "MSCommerce PowerShell module not found" -ForegroundColor Black -BackgroundColor Yellow
      $install = Read-Host "Do you want to install the MSCommerce PowerShell module?"
  
      if ($install -match "[yY]") {
        Install-Module MSCommerce -Repository PSGallery -Scope CurrentUser -AllowClobber -Force
      }else{
        Write-Host "MSCommerce PowerShell module is required." -ForegroundColor Black -BackgroundColor Yellow
        exit
      } 
    }
  
    # Connect to MSCommerce
    Write-Host "Connecting to MSCommerce" -ForegroundColor Cyan
    Connect-MSCommerce
}

$products = $null
$products = Get-MSCommerceProductPolicies -PolicyId AllowSelfServicePurchase | Where-Object {$_.PolicyValue -ne $selfServiceSetting}

if ($null -ne $products) {
    $products | ForEach {Update-MSCommerceProductPolicy -PolicyId AllowSelfServicePurchase -ProductId $_.ProductId -Value $selfServiceSetting}
}else{
    Write-Host "All products are already set to $selfServiceSetting" -ForegroundColor Green
}