<#
.Synopsis
  Download all libaries, folders and files from SPO.

.DESCRIPTION
  Script is based on https://www.sharepointdiary.com/2017/07/download-all-files-from-sharepoint-site.html from Salaudeen.

  Script copies all document libraries including all content from SharePoint Online (SPO) to a local folder. Logging is 
  done through a log file, path for log file can be set.

  You can re-run the script, it will check if local files exists. If the file on SPO is newer, then it will update the local file.

  Scripts counts the number of files copied and skipped.

.NOTES
  Name: Copy-SpSiteToNAS.ps1
  Author: R. Mens - LazyAdmin.nl
          S. Rajack - SharePointDiary.com
  Version: 1.1
  DateCreated:  2022
  Purpose/Change: init

.TODO
  Set log level - info/debug/error

.LINK
  https://lazyadmin.nl
  https://www.sharepointdiary.com/2017/07/download-all-files-from-sharepoint-site.html
#>

[CmdletBinding(DefaultParameterSetName="Default")]
param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "SharePoint Site Url"
    )]
  [string]$siteUrl,

  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter path where to download files to"
    )]
  [string]$downloadPath,

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path for log file location"
    )]
  [string]$logFilePath = "c:\temp\sp-archive.txt",

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Set log level"
  )]
  [ValidateSet("error", "warn", "info", "full")]
  [string]$logLevel = "full"
)
# Init Log file
$Global:logFile = [string]""
$Global:filesCopied = [int] 0
$Global:filesSkipped = [int] 0

Function Write-Log {
  <#
    .SYNOPSIS
    Save output in log file
  #>
  param(
      [Parameter(Mandatory = $true)][string] $message,
      [Parameter(Mandatory = $false)]
      [ValidateSet("FULL","INFO","WARN","ERROR")]
      [string] $level = "INFO"
  )
  
  # Create timestamp
  $timestamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")

  if ($logLevel -eq 'warn') {
    $allowedLevels = @(
      'warn',
      'error'
    )
  }elseif ($loglevel -eq 'info') {
    $allowedLevels = @(
      'info',
      'warn',
      'error'
    )
  }elseif ($loglevel -eq 'full') {
    $allowedLevels = @(
      'full',
      'info',
      'warn',
      'error'
    )
  }
  # Output errors also to console
  if ($allowedLevels -contains $level) {
    # Append content to log file
    Add-Content -Path $Global:logFile -Value "$timestamp [$level] - $message"
  }

  # Output errors also to console
  if ($level -eq 'ERROR') {
    Write-host $message -ForegroundColor red
  }
}

Function Get-DocLibraries {
  <#
    .SYNOPSIS
    Get all document libraries from the SharePoint site, except excluded ones
  #>

  #Excluded libraries
  $ExcludedLists = @(
    "FormServerTemplates", 
    "Images",
    "Pages", 
    "PreservationHoldlibrary",
    "SiteAssets", 
    "SitePages", 
    "Style_x0020_library"
  )

  Get-PnPList -Includes RootFolder | Where-Object {$_.BaseType -eq "Documentlibrary" -and $_.EntityTypeName -notin $ExcludedLists -and $_.Hidden -eq $False}
}

Function Get-SPOFiles {
  <#
  .SYNOPSIS
    List all folders and files from the given library
  #>
  param(
    [Parameter(Mandatory = $true)] $List
  )
  process{
    Try {
      # Get all Items from the library - with progress bar
      $global:itemCounter = 0

      Get-PnPListItem -List $List -PageSize 1000 -Fields ID -ScriptBlock { 
        Param($items) 
        $global:itemCounter += $items.Count;

        # Create progress bar
        $getItemsProgress = @{
          Activity         = "Get items from $($List.Title)"
          Status           = "Progress->"
          PercentComplete  = ($global:itemCounter/$list.itemCount) * 100
          CurrentOperation = "$($items.Count) of $($list.itemCount)"
        }
        Write-Progress @getItemsProgress
      } 
       
      Write-Progress -Activity "Completed gettings items from library $($List.Title)" -Completed
    }Catch{
      Write-Log -Message "Error Downloading library $($List.Title) : $($_.Exception.Message)" -level ERROR
    }
  }
}

Function Copy-SPOFiles(){
  <#
  .SYNOPSIS
    Download all folders and files from the given library
  #>
  param(
    [Parameter(Mandatory = $true)] $ListItems,
    [Parameter(Mandatory = $true)] $List,
    [Parameter(Mandatory = $true)] $localFolder
  )
  process{
    Try {
      # Create a Local Folder for the Document library, if it doesn't exist
      $libraryFolder = $localFolder +"\" +$List.RootFolder.Name

      If (!(Test-Path -LiteralPath $libraryFolder)) {
        New-Item -ItemType Directory -Path $libraryFolder | Out-Null
      }

      # Get all Subfolders of the library
      $SubFolders = $ListItems | Where {$_.FileSystemObjectType -eq "Folder" -and $_.FieldValues.FileLeafRef -ne "Forms"}
      $SubFolders | ForEach-Object {
          # Create local path for the sub folder
          $LocalFolderPath = $localFolder + ($_.FieldValues.FileRef.Substring($Web.ServerRelativeUrl.Length)) -replace "/","\"
          
          # Create Local Folder, if it doesn't exist
          If (!(Test-Path -LiteralPath $LocalFolderPath)) {
                  New-Item -ItemType Directory -Path $LocalFolderPath | Out-Null
          }
          Download-Files -ListItems
          Write-Log -Message "Created subfolder $LocalFolderPath" -level FULL
      }

      Write-Progress -CurrentOperation "downloadItems" -Activity "Completed downloading items from library $($List.Title)" -Completed
    }
    Catch {
      Write-Log -Message "Error Downloading library $($List.Title) : $($_.Exception.Message)" -level ERROR
    }
  }
}

Function Download-Files() {
    <#
  .SYNOPSIS
    Download all folders and files from the given library
  #>
  param(
    [Parameter(Mandatory = $true)] $ListItems,
    [Parameter(Mandatory = $true)] $List,
    [Parameter(Mandatory = $true)] $localFolder
  )
  process{
    # Get all Files from the folder
    $FilesColl =  $ListItems | Where {$_.FileSystemObjectType -eq "File"}
    $FileCounter = 0

    # Iterate through each file and download
    $FilesColl | ForEach-Object {

        # Frame the Parameters to download file
        $FileDownloadPath = ($localFolder + ($_.FieldValues.FileRef.Substring($Web.ServerRelativeUrl.Length)) -replace "/","\").Replace($_.FieldValues.FileLeafRef,'')
        
        $FileName = $_.FieldValues.FileLeafRef
        $SourceURL = $_.FieldValues.FileRef
        $FileModifiedDate = $_.FieldValues.Modified

        # Creating progressbar
        $FileCounter += 1;

        $downloadItemsProgress = @{
          Activity         = "Downloading items from $($List.Title)"
          Status           = "Progress->"
          PercentComplete  = ($FileCounter/$FilesColl.Count) * 100
          CurrentOperation = $FileName
        }
        Write-Progress @downloadItemsProgress

        #Check File Exists
        $FilePath = Join-Path -Path $FileDownloadPath -ChildPath $_.FieldValues.FileLeafRef

        If (-not(Test-Path -Path $FilePath -PathType Leaf)) {
          # Download the File
          Get-PnPFile -ServerRelativeUrl $SourceURL -Path $FileDownloadPath -FileName $FileName -AsFile -force
          Write-Log -Message "Downloaded $FileName from $SourceUrl " -level FULL
          $Global:filesCopied++
        }else{
          # Compare local and SPO file date
          if ($FileModifiedDate -gt ( Get-ChildItem -Path $FilePath | Select -ExpandProperty LastWriteTime)) {
            # SPO file is newer than local file, overwrite local file
            Get-PnPFile -ServerRelativeUrl $SourceURL -Path $FileDownloadPath -FileName $FileName -AsFile -force
            Write-Log -Message "Downloaded newer version of $FileName from $SourceUrl " -level FULL
            $Global:filesCopied++
          }else{
            Write-Log -Message "Skipped $FileName from $SourceUrl - Already exists" -level FULL
            $Global:filesSkipped++
          }
        }
      }
    }
  }
}

Function Get-NrOfDownloadedFiles() {
  <#
  .SYNOPSIS
    Download all folders and files from the given library
  #>
  param(
    [Parameter(Mandatory = $true)] $localFolder,
    [Parameter(Mandatory = $true)] $List
  )
  Process {
    $libraryFolder = $localFolder +"\" +$List.RootFolder.Name

    If (Test-Path -LiteralPath $libraryFolder) {
      (Get-ChildItem -Path $libraryFolder -File -Recurse).count
    }
  }
}

Function New-SPSiteArchiveFolder() {
  <#
  .SYNOPSIS
    Download all folders and files from the given library
  #>
  param(
    [Parameter(Mandatory = $true)] $title,
    [Parameter(Mandatory = $true)] $downloadPath
  )
  process {
    If (!(Test-Path -LiteralPath ($downloadPath +"\" +$title))) {
      New-Item -Path $downloadPath -Name $title -ItemType 'directory'
    }Else{
      $downloadPath +"\" +$title
    }
  }
}

# Connect to SharePoint Online
Connect-PnPOnline $SiteURL -Interactive
$Web = Get-PnPWeb
 
# Create Log file
$Global:logFile = $logFilePath + "\" + $Web.title + ".txt"
New-Item -Path $Global:logFile -Force | Out-Null

# Create folder for SharePoint site in Archive folder
$localFolder = New-SPSiteArchiveFolder -DownloadPath $downloadPath -title $web.title

# Get all the libraries
$documentLibraries = Get-DocLibraries
Write-Log -Message  "$(($documentLibraries).count) Document Libraries found" -level INFO

# Download all the files from each library if they contain items
ForEach($library in $documentLibraries)
{
  if ($library.itemCount -ne 0) {
    Write-Log -Message "Process document library : $($library.title)" -level INFO
    
    # Count nr of files in the doc library
    $SPOItems = Get-SPOFiles -List $library
    Write-Log -Message "$($SPOItems.count) files and folders found in $($library.title)" -level INFO
    
    # Download the files
    Copy-SPOFiles -List $library -ListItems $SPOItems -localFolder $localFolder

    # Count files in the local folder
    $CountLocalItems = Get-NrOfDownloadedFiles -List $library -localFolder $localFolder
    Write-Log -Message "$CountLocalItems files downloaded to the local folder" -level INFO
  }else{
    Write-Log -Message "Skipping document library : $($library.title) - No files found" -level WARN
  }
}

Write-Log -Message "---------------------------------------------" -level INFO
Write-Log -Message "Download completed" -level INFO
Write-Log -Message "---------------------------------------------" -level INFO
Write-Log -Message "Number of files copied $($Global:filesCopied)" -level INFO
Write-Log -Message "Number of files skipped $($Global:filesSkipped)" -level INFO
Write-Log -Message "---------------------------------------------" -level INFO  