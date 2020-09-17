<#
.SYNOPSIS
  
.DESCRIPTION
 This script will remove empty folders in SharePoint Online

.OUTPUTS
  Console output log

.NOTES
  Version:        1.0
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

#-----------------------------------------------------------[Functions]------------------------------------------------------------

#src https://www.sharepointdiary.com/2018/09/sharepoint-online-delete-empty-folders-using-powershell.html
Function Delete-PnPEmptyFolder([Microsoft.SharePoint.Client.Folder]$Folder)
{
    $FolderSiteRelativeURL = $Folder.ServerRelativeUrl.Substring($Web.ServerRelativeUrl.Length)

    # Process all Sub-Folders
    $SubFolders = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeURL -ItemType Folder

    Foreach($SubFolder in $SubFolders)
    {
        # Exclude "Forms" and Hidden folders
        If(($SubFolder.Name -ne "Forms") -and (-Not($SubFolder.Name.StartsWith("_"))))
        {
            # Call the function recursively
            Delete-PnPEmptyFolder -Folder $SubFolder
        }
    }

    # Get all files & Reload Sub-folders from the given Folder
    $Files = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeURL -ItemType File
    $SubFolders = Get-PnPFolderItem -FolderSiteRelativeUrl $FolderSiteRelativeURL -ItemType Folder
 
    If ($Files.Count -eq 0 -and $SubFolders.Count -eq 0)
    {
		
		#Delete the folder
		$ParentFolder = Get-PnPProperty -ClientObject $Folder -Property ParentFolder
		$ParentFolderURL = $ParentFolder.ServerRelativeUrl.Substring($Web.ServerRelativeUrl.Length)    

		if ($whatIf -ne $true)
		{
			#Delete the folder
			Write-Host "Remove folder:" $Folder.Name "in" $ParentFolderURL -ForegroundColor Red
			Remove-PnPFolder -Name $Folder.Name -Folder $ParentFolderURL -force:$force -Recycle
		}
		else
		{
			Write-host $parentFolder
			Write-Host "Empty folder:" $Folder.Name "in" $ParentFolderURL -ForegroundColor Red
		}
		$global:deleteLimitCounter
    }
}



#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Login 
$url = $siteUrl + '/' + $site
Connect-PnPOnline -Url $url -UseWebLogin

# Cleanup empty (1) folders
$Web = Get-PnPWeb
$List = Get-PnPList -Identity $libraryName -Includes RootFolder

Delete-PnPEmptyFolder $List.RootFolder