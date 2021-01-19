<#
.SYNOPSIS
  
.DESCRIPTION
 This script will merge duplicate folders. Duplicate folders are regonized by a (1) in the name.
 Files and folders in those duplicate folders are moved back to the original location.

 Before moving the file, the script will compare the file dates so that the latest file is kept in case 
 workers altered the wrong file.

.OUTPUTS
  

.NOTES
  Version:        0.1
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  05 jan 2021
  Purpose/Change: Initial script development
#>

# Reset error count
$error.clear()

# Get the script location
$rootPath = (Get-Item $PSScriptRoot).FullName


$promotions = Import-Csv -Delimiter ";" -Path ($rootPath + "\promotion-2020.csv")

foreach($user in $promotions){
    # Find user in Azure Ad

	Try{
		$ADUser = Get-AzureAdUser -SearchString $user.name -ErrorVariable userError
		Set-AzureAdUser -ObjectId $ADUser.ObjectId -JobTitle $user.jobtitle
	}
    Catch{
		Write-Host ("Failed to update " + $($user.name)) -ForegroundColor Red
	}
	Finally{
		
		
	}
}

If ($Error.Count -gt 0) {
	Write-Host "Users updated. Found $($Error.count) errors" -ForegroundColor DarkYellow   
}else{
	Write-Host "All users updated" -ForegroundColor Green
}