<#
.SYNOPSIS
  
.DESCRIPTION
 This script will merge duplicate folders. Duplicate folders are regonized by a (1) in the name.
 Files and folders in those duplicate folders are moved back to the original location.

 Before moving the file, the script will compare the file dates so that the latest file is kept in case 
 workers altered the wrong file.

.OUTPUTS
  Console output log

.NOTES
  Version:        1.1
  Author:         R. Mens
  Creation Date:  27 aug 2020
  Purpose/Change: Initial script development
#>



# SharePoint url
$siteUrl = 'https://lazyadmin.sharepoint.com/'

# Site url
$site = 'sites/lab01'

# Library name
$libraryName = 'Duplicates'

# Set test mode
$whatIf = $true

# Set force mode
# Only set to true if you have fully tested it. Script WON'T ask for confirmation before moving the file
$force = $false

# Set limits for testing
$moveLimit = 2

$moveLimitCounter = 0

#-----------------------------------------------------------[Functions]------------------------------------------------------------

# Recursively calls Get-PnpFolderItem for a given Document Library
# Based on: https://gist.github.com/josheinstein/3ace0c9f8e25d07583ceb57d13f71b2e

Function Get-PnpFolderItemRecursively($FolderSiteRelativeUrl) {
    
    # Get all items
    $items = @(Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeUrl)

    foreach ($item in $items) {

        # Strip the Site URL off the item path, because Get-PnpFolderItem wants it
        # to be relative to the site, not an absolute path.

        $itemPath = $item.ServerRelativeUrl -replace "^$(([Uri]$item.Context.Url).AbsolutePath)/",''

        #Write-Host 'Processing folder:' $itemPath

        # Check if item is a folder
        If ($item -is [Microsoft.SharePoint.Client.Folder]) 
        {
            
            # Check if foldername contains (1) on the end
            # If - if the folder name contains a (1) on the end, then it's a duplicate folder that we need to move or merge
            # Else - if the folder doesn't contain (1), then we open the folder and search through the next level

            if ($item.name  -like "*(1)") 
            {
         
                # Duplicate folder found
                Write-Host " - Duplicatie folder found: " $itemPath -ForegroundColor Yellow
            
                # Move content folder folder to the original location
                Move-FolderItemsRecursively($itemPath)
            }
            else
            {
                # Is doesn't contain (1), but it's a folder, search through next level by recursing into this function.
                Get-PnpFolderItemRecursively $itemPath
            }
        }
        else
        {
            # Item is a file
            # Check if items name contains a (1), if true, move the file

            if ($item.name  -like "*(1)") 
            {
                $targetPath = Create-TargetPath -itemPath $itemPath -targetPath $item["FileRef"].trim("*(1)") -relativePath $relativePath

                Write-Host $newTargetPath;

                Move-CustomItem -SiteRelativeUrl $itemPath -targetPath $targetPath -item $item
            }
            # Else skip to next
        }
    }
}

Function Move-FolderItemsRecursively($FolderSiteRelativeUrl) {

    # Get all items in this sub folder
    $items = @(Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeUrl)

    foreach ($item in $items) {

        # Strip the Site URL off the item path, because Get-PnpFolderItem wants it
        # to be relative to the site, not an absolute path.
        
        $itemPath = $item.ServerRelativeUrl -replace "^$(([Uri]$item.Context.Url).AbsolutePath)/",''

        # If this is a directory, recurse into this function.
        # Otherwise, build target path and move file

        if ($item -is [Microsoft.SharePoint.Client.Folder]) 
        {
            Move-FolderItemsRecursively $itemPath
        }
        else 
        {
            Write-host ' - Processing file:' $item.Name

            $targetPath = Create-TargetPath -itemPath $itemPath -item $item
            
            Move-CustomItem -SiteRelativeUrl $itemPath -targetPath $targetPath -item $item
        }
    }
}

# Create new targetPath based on subfolder(s)

Function Create-TargetPath {
    [CmdletBinding()]
    param(
         [parameter (Mandatory=$true)]
         $itemPath,

         [parameter (Mandatory=$true)]
         $item,

         [parameter (Mandatory=$false)]
         $relativePath
     )

    process
	{
        # Build new path
        $path = $itemPath.replace($item.name,'') 
        $targetPath = "/" + $site + "/" + $path + $item.name

        if ($whatIf -ne $true)
        {
            # Check if target folder exists, create if necessary
            Write-host ' - Check if target folder exists' $path.replace('(1)', '') -BackgroundColor DarkMagenta;
            $result = Resolve-PnPFolder -SiteRelativePath $path.replace('(1)', '') -ErrorAction SilentlyContinue
        }
        else{
            Write-host ' - Create target folder if it does not exists' $path.replace('(1)', '') -BackgroundColor DarkMagenta;
        }

        Write-Output $targetPath.replace('(1)', '')
    }
}

# Move file to original folder
Function Move-CustomItem  {
    [CmdletBinding()]
    param(
         [parameter (Mandatory=$true)]
         $siteRelativeUrl,

         [parameter (Mandatory=$true)]
         $targetPath,

         [parameter (Mandatory=$true)]
         $item
     )

    process
	{
        $moveFile = Compare-FileDates -sourceFilePath $siteRelativeUrl -targetFilePath $targetPath;
		$global:moveLimitCounter++

        if ($moveFile -eq $true) 
        {

			if ($moveLimitCounter -eq $moveLimit)
			{
				Write-Warning 'Move limit reached'
				exit;	
			}

            if ($whatIf -ne $true)
            {
				# Move the file
				Write-host '   - Move item to' $targetPath -BackgroundColor DarkYellow;
				Move-PnPFile -SiteRelativeUrl $siteRelativeUrl -TargetUrl $targetPath -OverwriteIfAlreadyExists -Force:$force
				Write-Host "`r`n"
				
            }
            else
            {
                Write-host '   - Move file from' $siteRelativeUrl -BackgroundColor DarkCyan
				Write-host '     to' $targetPath -BackgroundColor DarkCyan
				Write-Host "`r`n"
            }
        }
    }    
}

# Check if file already exists in target location
# If file exists, we need to compare the dates to keep the latest files

Function Compare-FileDates () 
{
    [CmdletBinding()]
    param(
         [parameter (Mandatory=$true)]
         $targetFilePath,

         [parameter (Mandatory=$true)]
         $sourceFilePath
     )

    $targetFileExists = Get-PnPFile -Url $targetFilePath -ErrorAction SilentlyContinue
    
    If($targetFileExists)
    {
        $sourceFile = Get-PnPFile -Url $sourceFilePath -AsListItem
        $targetFile = Get-PnPFile -Url $targetFilePath -AsListItem

        $sourceFileDate = Get-date $sourceFile['Modified']
        $targetFileDate = Get-date $targetFile['Modified']

        write-host ' - Comparing files dates: duplicate file: '$sourceFileDate 'original file: '$targetFileDate

        # Check if source file is newer then the target file
        If ($sourceFile['Modified'] -gt $targetFile['Modified']) 
        {
            write-host '    - Duplicate file is newer, move the file' -BackgroundColor DarkGreen
            write-output $true
        }
        else
        {
			# Remove file
			if ($whatIf -ne $true)
            {
				Write-host '    - Target file is newer. Removing duplicate file' -BackgroundColor DarkRed
				Write-Host "`r`n"
				Remove-PnPFile -SiteRelativeUrl $sourceFilePath -Recycle -Force:$force
			}
			else
			{
				Write-Host 'Remove file' $sourceFilePath  -ForegroundColor Red
				Write-Host "`r`n"
			}
            write-output $false
        }
    }
    else
    {
        # Target file doesn't exists
        Write-host ' - Target file does not exist' -BackgroundColor DarkGreen
        Write-Output $true
    }

}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Login 
$url = $siteUrl + '/' + $site
Connect-PnPOnline -Url $url -UseWebLogin

# Get list of all folders in the document library
Get-PnpFolderItemRecursively -FolderSiteRelativeUrl $libraryName

# Target multiple lists 
# Optional - only if you need to go through multiple document libraries
# $allLists = Get-PnPList | Where-Object {$_.BaseTemplate -eq 101}

# If you need to process multiple document libraries:
# $allItems = Get-PnPListItem -List $allList -Fields "FileLeafRef", "FileDirRef"
    
# Loop through each item in the document library and process all folders
#foreach ($item in $allItems) {

#    Write-Host 'Processing folder:' $item["FileLeafRef"]
#  
#    #get relative path
#    $relativePath = $libraryName + "/" + $item["FileLeafRef"]
    
#}