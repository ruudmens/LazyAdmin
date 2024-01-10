<#
.SYNOPSIS
  Closes Teams and removes the local cache

.DESCRIPTION
  This script will close Teams if it's open and remove the local cache

.OUTPUTS
  none

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  10 jan 2024
  Purpose/Change: Initial script development

.EXAMPLE
  Just run the script
#>

$clearCache = Read-Host "Do you want to delete the Teams Cache (Y/N)?"

if ($clearCache.ToUpper() -eq "Y"){
  Write-Host "Closing Teams" -ForegroundColor Cyan
  
  try{
    if (Get-Process -ProcessName ms-teams -ErrorAction SilentlyContinue) { 
        Stop-Process -Name ms-teams -Force
        Start-Sleep -Seconds 3
        Write-Host "Teams sucessfully closed" -ForegroundColor Green
    }else{
        Write-Host "Teams is already closed" -ForegroundColor Green
    }
  }catch{
      Write-Warning $_
  }

  Write-Host "Clearing Teams cache" -ForegroundColor Cyan

  
  try{
    Remove-Item -Path "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe" -Recurse -Force -Confirm:$false
    Write-Host "Teams cache removed" -ForegroundColor Green
  }catch{
    Write-Warning $_
  }

  Write-Host "Cleanup complete... Trying to launching Teams" -ForegroundColor Green
  Start-Process -FilePath "C:\Program Files\WindowsApps\MSTeams_23335.219.2592.8659_x64__8wekyb3d8bbwe\ms-teams.exe"
}