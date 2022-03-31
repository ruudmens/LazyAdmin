<#
.SYNOPSIS
  Create local user acc

.DESCRIPTION
  Creates a local user account on de computer. Requires RunAs permissions to run

.OUTPUTS
  none

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  25 march 2022
  Purpose/Change: Initial script development
#>

# Configuration
$username = "LazyTestUser"   # UserName
$fullName = "Lazy Test User" # Full name
$logFile = "\\server\folder\log.txt"

Function Write-Log {
  param(
      [Parameter(Mandatory = $true)][string] $message,
      [Parameter(Mandatory = $false)]
      [ValidateSet("INFO","WARN","ERROR")]
      [string] $level = "INFO"
  )
  # Create timestamp
  $timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")

  # Append content to log file
  Add-Content -Path $logFile -Value "$timestamp [$level] - $message"
}

Function Create-LocalUser {
    process {
      try {
        New-LocalUser "$username" -Password $password -FullName "$fullname" -Description "local user" -ErrorAction stop
        Write-Log -message "$username local user created"

        # Add new user to administrator group
        Add-LocalGroupMember -Group "Users" -Member "$username" -ErrorAction stop
        Write-Log -message "$username added to the local users group"
      }catch{
        Write-log -message "Creating local account failed" -level "ERROR"
      }
    }    
}

# Enter the password
Write-Host "Enter the password for the local user account" -ForegroundColor Cyan
$password = Read-Host -AsSecureString

Write-Log -message "#########"
Write-Log -message "$env:COMPUTERNAME - Create local user account"

Create-LocalUser

Write-Log -message "#########"