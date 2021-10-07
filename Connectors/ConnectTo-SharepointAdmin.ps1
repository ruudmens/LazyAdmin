<#
    .SYNOPSIS
        Connects to PNP Online no connection exists. Checks for PnPOnline Module
  #>
  
process {
  # Check if EXO is installed and connect if no connection exists
  if ((Get-Module -ListAvailable -Name PnP.PowerShell) -eq $null)
  {
    Write-Host "PnPOnline Module is required, do you want to install it?" -ForegroundColor Yellow
      
    $install = Read-Host Do you want to install module? [Y] Yes [N] No 
    if($install -match "[yY]") 
    { 
      Write-Host "Installing PnP PowerShell module" -ForegroundColor Cyan
      Install-Module PnP.PowerShell -Repository PSGallery -AllowClobber -Force
    } 
    else
    {
	    Write-Error "Please install PnP Online module."
    }
  }


  if ((Get-Module -ListAvailable -Name PnP.PowerShell) -ne $null) 
  {
	  Connect-PnPOnline -Url $sharepointAdminUrl -Interactive
  }
  else{
    Write-Error "Please install PnP PowerShell module."
  }
}