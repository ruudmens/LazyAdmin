Write-Host "Remove phishing mail from all mailboxes"
Write-Host "Make sure you use an unique phrase for the subject"
Write-Host "and keep the dates between the event date"

$job = Read-Host "Give the search job a unique name"
$subject = Read-Host "Enter a part of the subject including wildcards *"
$startDate = Read-Host "Enter start date: YYYY-MM-DD"
$endDate = Read-Host "Enter end date: YYYY-MM-DD"

# Connecting
Connect-IPPSSession -UserPrincipalName rudymens@thunnissen.nl

# Creating ComplianceSearch
New-ComplianceSearch -name $job -ExchangeLocation All -ContentMatchQuery "(c:c)(date=$startDate..$endDate)(subjecttitle:$subject)"

Set-ComplianceSearch -identity $job -ExchangeLocation All -ContentMatchQuery "(c:c)(date=$startDate..$endDate)(subjecttitle:$subject)"

# Start the complianceSearch
Start-ComplianceSearch -Identity $job

# Check if job is completed
Do{
    Write-Host "Search still running" -ForegroundColor Cyan
    Start-Sleep 5
}Until((Get-ComplianceSearch -Identity $job | select Status -ExpandProperty Status) -eq 'Completed')

Write-Host "Compliance search completed" -ForegroundColor Green

# Check if preview is completed
$jobName = $job + "_Preview"

# Generate a preview
Write-host "Creating new ComplianceSearchAction"
New-ComplianceSearchAction -SearchName $job -Preview

Do{
    Write-Host "Preview is being generated" -ForegroundColor Cyan
    Start-Sleep 5
}Until((Get-ComplianceSearchAction $jobName| select Status -ExpandProperty Status) -eq 'Completed')

Write-Host "Preview completed" -ForegroundColor Green

Write-Warning "Phishing mail found in the following mailboxes"


Get-ComplianceSearchAction $jobName | Select -ExpandProperty ExchangeLocation | ft
$confirmation = Read-Host "Do you want to remove the item from the mailboxes above?"

if ($confirmation -eq 'y') {
    New-ComplianceSearchAction -SearchName $job  -Purge -PurgeType SoftDelete
}