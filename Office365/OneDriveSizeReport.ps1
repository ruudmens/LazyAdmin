<#
.SYNOPSIS
  Create report of all OneDrive sizes

.DESCRIPTION
  Collects all the OneDrive stats

.EXAMPLE
  Get-OneDriveSizeReport.ps1 -url "https://contoso-admin.sharepoint.com"

  Generate the onedrive size report and stores the csv file in the script root location.

.EXAMPLE
  Get-OneDriveSizeReport.ps1 url "https://contoso-admin.sharepoint.com" -path c:\temp\reportoneDrive.csv

  Store CSV report in c:\temp\reportoneDrive.csv

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  27 sep 2021
  Purpose/Change: Initial script development
  Link:           https://lazyadmin.nl/powershell/onedrive-storage-metrics-report
#>

param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter your SharePoint Admin URL. For exampl https://contoso-admin.sharepoint.com"
  )]
  [string]$url,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\MailboxSizeReport-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function ConnectTo-SharePoint {
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
	    Connect-PnPOnline -Url $url -Interactive
    }
    else{
      Write-Error "Please install PnP PowerShell module."
    }
  }
}

Function ConvertTo-Gb {
  <#
    .SYNOPSIS
        Convert mailbox size to Gb for uniform reporting.
  #>
  param(
    [Parameter(
      Mandatory = $true
    )]
    [string]$size
  )
  process {
    if ($size -ne $null) {
      $sizeInGb = ($size / 1024)

      return [Math]::Round($sizeInGb,2,[MidPointRounding]::AwayFromZero)
    }
  }
}


Function Get-OneDriveStats {
  <#
    .SYNOPSIS
        Get the mailbox size and quota
  #>
  process {
    $oneDrives = Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'" -Detailed | Select Title,Owner,StorageQuota,StorageQuotaWarningLevel,StorageUsageCurrent,LastContentModifiedDate,Status
    $i = 0

    $oneDrives | ForEach {
  
      [pscustomobject]@{
        "Display Name" = $_.Title
        "Owner" = $_.Owner
        "Onedrive Size (Gb)" = ConvertTo-Gb -size $_.StorageUsageCurrent
        "Storage Warning Quota (Gb)" = ConvertTo-Gb -size $_.StorageQuotaWarningLevel
        "Storage Quota (Gb)" = ConvertTo-Gb -size $_.StorageQuota
        "Last Used Date" = $_.LastContentModifiedDate
        "Status" = $_.Status
      }

      $currentUser = $_.Title
      Write-Progress -Activity "Collecting OneDrive Sizes" -Status "Current Count: $i" -PercentComplete (($i / $oneDrives.Count) * 100) -CurrentOperation "Processing OneDrive: $currentUser"
      $i++;
    }
  }
}

# Connect to SharePoint Online
ConnectTo-SharePoint

# Get OneDrive status
Get-OneDriveStats | Export-CSV -Path $path -NoTypeInformation

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green
}else{
  Write-Host "Failed to create report" -ForegroundColor Red
}


# Close Exchange Online Connection
$close = Read-Host Close PNP Online connection? [Y] Yes [N] No 

if ($close -match "[yY]") {
  Disconnect-PnPOnline -Confirm:$false | Out-Null
}