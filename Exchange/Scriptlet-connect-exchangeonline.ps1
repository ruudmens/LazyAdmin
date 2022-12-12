Function ConnectTo-EXO {
  <#
    .SYNOPSIS
        Connects to EXO when no connection exists. Checks for EXO v3 module
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    [string]$adminUPN
  )
  
  process {
    # Check if EXO is installed and connect if no connection exists
    if ($null -eq (Get-Module -ListAvailable -Name ExchangeOnlineManagement))
    {
      Write-Host "Exchange Online PowerShell v3 module is requied, do you want to install it?" -ForegroundColor Yellow
      
      $install = Read-Host Do you want to install module? [Y] Yes [N] No 
      if($install -match "[yY]") { 
        Write-Host "Installing Exchange Online PowerShell v3 module" -ForegroundColor Cyan
        Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
      }else{
	      Write-Error "Please install EXO v3 module."
      }
    }

    if ($null -ne (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
      # Check which version of Exchange Online is installed
      if (Get-Module -ListAvailable -Name ExchangeOnlineManagement | Where-Object {$_.version -like "3.*"} ) {
        # Check if there is a active EXO sessions
        if ((Get-ConnectionInformation).tokenStatus -ne 'Active') {
          write-host 'Connecting to Exchange Online' -ForegroundColor Cyan
          Connect-ExchangeOnline -UserPrincipalName $adminUPN
        }
      }else{
        # Check if there is a active EXO sessions
        $psSessions = Get-PSSession | Select-Object -Property State, Name
        If (((@($psSessions) -like '@{State=Opened; Name=ExchangeOnlineInternalSession*').Count -gt 0) -ne $true) {
          write-host 'Connecting to Exchange Online' -ForegroundColor Cyan
          Connect-ExchangeOnline -UserPrincipalName $adminUPN
        }
      }
    }else{
      Write-Error "Please install EXO v3 module."
    }
  }
}