$spolHostName = "https://thunnissenonline.sharepoint.com"
$spolSiteRelativeUrl = "/teams/awesome-test-group"
$spolDocLibTitle = "document-library-title"
$azStorageAccountKey = ""
$azStorageAccountName = "thunnissenblob"
$azStorageContainerName = "azure-storage-container-name"
$localBaseFolderName = "local-base-folder-name"

$spolSiteUrl = $spolHostName + $spolSiteRelativeUrl

$spolLibItems = m365 spo listitem list --webUrl $spolSiteUrl --title $spolDocLibTitle --fields 'FileRef,FileLeafRef' --filter "FSObjType eq 0" -o json | ConvertFrom-Json

if ($spolLibItems.Count -gt 0) {
  ForEach ($spolLibItem in $spolLibItems) {
    $spolLibFileRelativeUrl = $spolLibItem.FileRef
    $spolFileName = $spolLibItem.FileLeafRef

    $spolLibFolderRelativeUrl = $spolLibFileRelativeUrl.Substring(0, $spolLibFileRelativeUrl.lastIndexOf('/'))

    $localDownloadFolderPath = Join-Path $localFileDownloadFolderPath $localBaseFolderName $spolLibFolderRelativeUrl

    If (!(test-path $localDownloadFolderPath)) {
      $message = "Target local folder $localDownloadFolderPath not exist"
      Write-Host $message -ForegroundColor Yellow

      New-Item -ItemType Directory -Force -Path $localDownloadFolderPath | Out-Null

      $message = "Created target local folder at $localDownloadFolderPath"
      Write-Host $message -ForegroundColor Green
    }
    else {
      $message = "Target local folder exist at $localDownloadFolderPath"
      Write-Host $message -ForegroundColor Blue
    }

    $localFilePath = Join-Path $localDownloadFolderPath $spolFileName

    $message = "Processing SharePoint file $spolFileName"
    Write-Host $message -ForegroundColor Green

    m365 spo file get --webUrl $spolSiteUrl --url $spolLibFileRelativeUrl --asFile --path $localFilePath

    $message = "Downloaded SharePoint file at $localFilePath"
    Write-Host $message -ForegroundColor Green
  }

  $localFolderToSync = Join-Path $localFileDownloadFolderPath $localBaseFolderName
  az storage blob sync --account-key $azStorageAccountKey --account-name $azStorageAccountName -c $azStorageContainerName -s $localFolderToSync --only-show-errors | Out-Null

  $message = "Syncing local folder $localFolderToSync with Azure Storage Container $azStorageContainerName is completed"
  Write-Host $message -ForegroundColor Green
}
else {
  Write-Host "No files in $spolDocLibTitle library" -ForegroundColor Yellow
}