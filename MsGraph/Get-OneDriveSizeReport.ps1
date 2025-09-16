<#
.SYNOPSIS
  Create report of all OneDrive sizes using Microsoft Graph API

.DESCRIPTION
  Collects all the OneDrive stats using Microsoft Graph API instead of PnP PowerShell

.EXAMPLE
  .\OneDriveSizeReport-MsGraph.ps1

  Generate the OneDrive size report and stores the csv file in the script root location.

.EXAMPLE
  .\OneDriveSizeReport-MsGraph.ps1 -path c:\temp\reportoneDrive.csv

  Store CSV report in c:\temp\reportoneDrive.csv

.NOTES
  Name:           Get-OneDriveSizeReports.ps1
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  March 31, 2025
  Purpose/Change: Convert to Microsoft Graph API
#>

param(
[Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\OneDriveSizReport-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

Function ConnectTo-MgGraph {
  <#
    .SYNOPSIS
        Connects to Microsoft Graph if no connection exists
  #>
  
  process {
    # Check if Microsoft Graph module is installed
    if ((Get-Module -ListAvailable -Name Microsoft.Graph) -eq $null) {
      Write-Host "Microsoft Graph Module is required, do you want to install it?" -ForegroundColor Yellow
      
      $install = Read-Host Do you want to install module? [Y] Yes [N] No 
      if($install -match "[yY]") { 
        Write-Host "Installing Microsoft Graph module" -ForegroundColor Cyan
        Install-Module Microsoft.Graph -Repository PSGallery -AllowClobber -Force
      } 
      else {
        Write-Error "Please install Microsoft Graph module."
        exit
      }
    }

    # Connect to Microsoft Graph
    try {
      Connect-MgGraph -Scopes "Sites.Read.All", "User.Read.All" -ErrorAction Stop
    }
    catch {
      Write-Error "Could not connect to Microsoft Graph. Error: $_"
      exit
    }
  }
}

Function ConvertTo-Gb {
  <#
    .SYNOPSIS
        Convert storage size to GB for uniform reporting.
  #>
  param(
    [Parameter(Mandatory = $true)]
    [long]$size
  )
  process {
    if ($size -ne $null) {
      $sizeInGb = ($size / 1024 / 1024 / 1024)  # Convert bytes to GB
      return [Math]::Round($sizeInGb, 2, [MidPointRounding]::AwayFromZero)
    }
    else {
      return 0
    }
  }
}

Function Get-OneDriveStats {
  <#
    .SYNOPSIS
        Get OneDrive size and quota using Microsoft Graph
  #>
  process {
    # Get all users with OneDrive
    Write-Host "Getting users with OneDrive..." -ForegroundColor Cyan
    $users = Get-MgUser -Filter 'assignedLicenses/$count eq 0' -ConsistencyLevel eventual -CountVariable unlicensedUserCount -All | 
                    Select  'DisplayName','userPrincipalName','id' 
    
    $results = @()
    $i = 0
    
    foreach ($user in $users) {
      $i++
      $currentUser = $user.DisplayName
      Write-Progress -Activity "Collecting OneDrive Sizes" -Status "Current Count: $i of $($users.Count)" -PercentComplete (($i / $users.Count) * 100) -CurrentOperation "Processing OneDrive: $currentUser"
      
      try {
        # Get user's OneDrive site
        $oneDriveSite = Get-MgUserDrive -UserId $user.Id -ErrorAction SilentlyContinue
        write-host $oneDriveSite
        
        if ($oneDriveSite) {
          # Get root folder to find last modified date
          $rootFolder = Get-MgDriveRoot -DriveId $oneDriveSite.Id -ErrorAction SilentlyContinue
          
          # Create custom object with OneDrive information
          $oneDriveInfo = [PSCustomObject]@{
            "Display Name"           = $user.DisplayName
            "Owner"                  = $user.UserPrincipalName
            "OneDrive Size (Gb)"     = ConvertTo-Gb -size $oneDriveSite.Quota.Used
            "Storage Warning Quota (Gb)" = ConvertTo-Gb -size $oneDriveSite.Quota.Warning
            "Storage Quota (Gb)"     = ConvertTo-Gb -size $oneDriveSite.Quota.Total
            "Last Used Date"         = $rootFolder.LastModifiedDateTime
            "Status"                 = $oneDriveSite.Status
          }
          
          $results += $oneDriveInfo
        }
      }
      catch {
        Write-Host "Error processing $($user.UserPrincipalName): $_" -ForegroundColor Yellow
      }
    }
    
    Write-Progress -Activity "Collecting OneDrive Sizes" -Completed
    return $results
  }
}

# Connect to Microsoft Graph
ConnectTo-MgGraph

# Get OneDrive stats and export to CSV
Get-OneDriveStats | Export-CSV -Path $path -NoTypeInformation

if ((Get-Item $path).Length -gt 0) {
  Write-Host "Report finished and saved in $path" -ForegroundColor Green
} else {
  Write-Host "Failed to create report" -ForegroundColor Red
}

# Disconnect Microsoft Graph
$close = Read-Host "Disconnect from Microsoft Graph? [Y] Yes [N] No"
if ($close -match "[yY]") {
  Disconnect-MgGraph | Out-Null
  Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Green
}