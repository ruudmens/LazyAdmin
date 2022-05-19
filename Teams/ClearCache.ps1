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
  Creation Date:  19-5-2022
  Purpose/Change: Initial script development

.EXAMPLE
  Just run the script
#>

$clearCache = Read-Host "Do you want to delete the Teams Cache (Y/N)?"
$clearCache = $clearCache.ToUpper()

if ($clearCache -eq "Y"){
  Write-Host "Closing Teams" -ForegroundColor Cyan
  
  try{
    if (Get-Process -ProcessName Teams -ErrorAction SilentlyContinue) { 
        Get-Process -ProcessName Teams | Stop-Process -Force
        Start-Sleep -Seconds 3
        Write-Host "Teams sucessfully closed" -ForegroundColor Green
    }else{
        Write-Host "Teams is already closed" -ForegroundColor Green
    }
  }catch{
      echo $_
  }

  Write-Host "Clearing Teams cache" -ForegroundColor Cyan

  try{
    Get-ChildItem -Path $env:APPDATA\"Microsoft\teams" | Remove-Item -Recurse -Confirm:$false
    Write-Host "Teams cache removed" -ForegroundColor Green
  }catch{
    echo $_
  }

  Write-Host "Cleanup complete... Launching Teams" -ForegroundColor Green
  Start-Process -FilePath $env:LOCALAPPDATA\Microsoft\Teams\current\Teams.exe
}