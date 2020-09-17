<#
.SYNOPSIS
	Remove all files older than given age, cleanup empty folders when done.

.DESCRIPTION
	Checks given path, if exists removes all files older than given age on the given path and subfolders. By default it will remove empty
	folders when done, but you can also disable this feature. 
	Run the script with the option -WhatIf to test the output.

.PARAMETER <path>
	Path to remove files and empty folders from

.PARAMETER <age> / <olderThan>
	Integer, files older than given number (in days) will be deleted.

.PARAMETER <removeEmptyFolders> (default = true)
	When set to false, empty folders wil not be deleted.

.PARAMETER <WhatIf> (default = false)
	Run the script in test mode to see the result

.PARAMETER <Force> (default = false)
	Set Force to true to remove hidden and readonly files

.EXAMPLE
	Remove files older than 7 days from given path	

	.\removeOldFiles.ps1 -path 'd:\path\to\remove' -age 7

.EXAMPLE
	Remove files older than 7 days from given path and leave empty folders	

	.\removeOldFiles.ps1 -path 'd:\path\to\remove' -age 7 -removeEmptyFolders:$False

.EXAMPLE
	Run script in test mode to see what gets removed. This will no remove any files

	.\removeOldFiles.ps1 -path 'd:\path\to\remove' -age 7 -WhatIf

.EXAMPLE
	Also remove hidden and read-only files

	.\removeOldFiles.ps1 -path 'd:\path\to\remove' -age 7 -Force
   
.NOTES
	Version:        1.1
	Author:         R. Mens
	Blog:			http://lazyadmin.nl
	Creation Date:  08 feb 2017
	Purpose/Change: Set -Force as optional switch and default to false

.LINK
	https://github.com/ruudmens/SysAdminScripts/tree/master/RemoveOldFiles
	https://gallery.technet.microsoft.com/Remove-old-files-and-16041dc8

#>
#-----------------------------------------------------------[Execution]------------------------------------------------------------
[CmdletBinding()]
PARAM(	
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true)]
	[string]$path,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true)]
	[Alias('age')]
	[int]$olderThan,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$removeEmptyFolders=$true,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$whatIf=$false,
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$false)]
	[switch]$force=$false
)
BEGIN
{
	If ($PSBoundParameters['Debug']) {
		$DebugPreference = 'Continue'
	}
}
PROCESS
{
	#region CHECK PATH
	Write-Debug "Check if path $path exists"
	If ( !$(Try { Test-Path $path.trim() } Catch { $false }) ) {
		Write-host "ERROR: Path $path does not exists" -ForegroundColor Red
		exit 
	}
	#endregion

	#region REMOVE FILES
	#----------------------------[Remove old files]-------------------------------
	$dateTime = (Get-Date).AddDays(-$olderThan)
	Write-Debug "File from before $dateTime we be deleted"
	
	Write-Debug "Following files will be deleted:"
	
	Get-ChildItem -Path $Path -Recurse -File -Force:$force | Where-Object { ( $_.LastWriteTime -lt $dateTime  -and $_.FullName -notlike '*DfsrPrivate*' )} | `
		ForEach-Object `
		{ `
			Write-Debug $_.FullName ` 
			Remove-Item -Path $_.FullName -ErrorAction SilentlyContinue -Force:$force -WhatIf:$whatIf  ` 
		}
	#endregion
	
	#region REMOVE FOLDERS
	#---------------------------[Remove empty folders]----------------------------
	If ($removeEmptyFolders)
	{
		Write-Debug "Removing empty folders"
		Get-ChildItem -Path $Path -Recurse -Directory -Force:$force | `
		Where-Object `
		{ `
			( (Get-ChildItem -Path $_.FullName -Recurse -File -Force:$force) -eq $null  -and $_.FullName -notlike '*DfsrPrivate*')`
		} | `
		ForEach-Object `
		{ `
			Write-Debug $_.FullName ` 
			Remove-Item -Path $_.FullName -Recurse -Force:$force -WhatIf:$WhatIf `
		}
	}
	#endregion
	Write-Debug "All done"	
}