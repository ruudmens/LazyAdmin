<#
.SYNOPSIS
    Finds students and alumni on retiring Microsoft 365 Education licenses that actively use their mailbox.

.DESCRIPTION
    Lists the education licenses in the tenant, collects all users with a student or alumni license
    (Office 365 A1, Student Use Benefit, paid student, Exchange Online for Alumni) and matches them
    against the Microsoft 365 mailbox and OneDrive usage reports.

    The result shows per license type how many users have a mailbox, how many used it recently,
    and how much mailbox and OneDrive storage they use.

    Requires: Microsoft.Graph.Users, Microsoft.Graph.Reports, Microsoft.Graph.Identity.DirectoryManagement
    Role:     Global Reader or Reports Reader
    Note:     Turn off "Display concealed user, group, and site names in all reports" in
              Microsoft 365 admin center > Settings > Org settings > Reports before running.

.PARAMETER ActiveDays
    Number of days of mailbox activity that count as "in use". Default 90.

.PARAMETER ExportPath
    Path of the CSV export. Default .\EDU-Student-Mailbox-Usage.csv

.EXAMPLE
    .\Get-EduStudentMailboxUsage.ps1

.EXAMPLE
    .\Get-EduStudentMailboxUsage.ps1 -ActiveDays 30 -ExportPath C:\Temp\students.csv

.NOTES
    Author: Rudy Mens - https://lazyadmin.nl
#>

#Requires -Modules Microsoft.Graph.Users, Microsoft.Graph.Reports, Microsoft.Graph.Identity.DirectoryManagement

[CmdletBinding()]
param(
    [int]$ActiveDays = 90,
    [string]$ExportPath = '.\EDU-Student-Mailbox-Usage.csv'
)

Connect-MgGraph -Scopes 'User.Read.All', 'Organization.Read.All', 'Reports.Read.All' -NoWelcome

$cutoff   = (Get-Date).AddDays(-$ActiveDays)
$tempPath = [System.IO.Path]::GetTempPath()

# Map the education SKU part numbers to the groups we care about
function Get-LicenseGroup ($skuPartNumber) {
    switch -Regex ($skuPartNumber) {
        'STUUSEBNFT'                 { 'Student Use Benefit'; break }
        '^STANDARDWOFFPACK_STUDENT$' { 'Office 365 A1 (student)'; break }
        '^STANDARDWOFFPACK_FACULTY$' { 'Office 365 A1 (faculty)'; break }
        'ALUMNI'                     { 'Exchange Online for Alumni'; break }
        'STUDENT'                    { 'Paid student'; break }
    }
}

# 1. Education licenses in the tenant
$eduSkus = Get-MgSubscribedSku -All | ForEach-Object {
    $group = Get-LicenseGroup $_.SkuPartNumber

    # Only count paid student licenses that include Exchange Online.
    # This skips student add-ons like ATP_ENTERPRISE_STUDENT (Defender for Office 365)
    if ($group -eq 'Paid student' -and -not ($_.ServicePlans.ServicePlanName -match '^EXCHANGE_S_')) {
        $group = $null
    }

    if ($group) {
        [PSCustomObject]@{
            SkuPartNumber = $_.SkuPartNumber
            SkuId         = $_.SkuId
            Group         = $group
            Assigned      = $_.ConsumedUnits
        }
    }
}

if (-not $eduSkus) {
    Write-Warning 'No education student, alumni or A1 licenses found in this tenant.'
    return
}

Write-Host 'Education licenses in this tenant:' -ForegroundColor Cyan
$eduSkus | Sort-Object Group | Format-Table SkuPartNumber, Group, Assigned -AutoSize

# 2. Users with a student or alumni license
# When a user has more than one, the license with the lowest rank wins
$rank = @{
    'Paid student'               = 1
    'Student Use Benefit'        = 2
    'Office 365 A1 (student)'    = 3
    'Exchange Online for Alumni' = 4
}

$licensedUsers = @{}

foreach ($sku in $eduSkus | Where-Object { $rank.ContainsKey($_.Group) }) {
    Write-Host "Getting users with $($sku.SkuPartNumber)..." -ForegroundColor Cyan

    $users = Get-MgUser -All -Filter "assignedLicenses/any(x:x/skuId eq $($sku.SkuId))" `
        -ConsistencyLevel eventual -CountVariable userCount `
        -Property Id, UserPrincipalName, DisplayName, AccountEnabled

    foreach ($user in $users) {
        $key = $user.UserPrincipalName.ToLower()
        if (-not $licensedUsers.ContainsKey($key) -or $rank[$sku.Group] -lt $rank[$licensedUsers[$key].Group]) {
            $licensedUsers[$key] = [PSCustomObject]@{ User = $user; Group = $sku.Group }
        }
    }
}

# 3. Mailbox and OneDrive usage reports (last 180 days)
Write-Host 'Downloading mailbox and OneDrive usage reports...' -ForegroundColor Cyan

$mailboxFile  = Join-Path $tempPath 'MailboxUsageDetail.csv'
$oneDriveFile = Join-Path $tempPath 'OneDriveUsageDetail.csv'

# Remove results from a previous run, so we never read an old report
Remove-Item $mailboxFile, $oneDriveFile -ErrorAction SilentlyContinue

# Invoke-MgGraphRequest instead of the Get-MgReport* cmdlets: the cmdlets can fail on
# large downloads with "PercentComplete cannot be greater than 100"
try {
    Invoke-MgGraphRequest -Method GET -Uri "v1.0/reports/getMailboxUsageDetail(period='D180')" -OutputFilePath $mailboxFile -ErrorAction Stop
    Invoke-MgGraphRequest -Method GET -Uri "v1.0/reports/getOneDriveUsageAccountDetail(period='D180')" -OutputFilePath $oneDriveFile -ErrorAction Stop
}
catch {
    Write-Error "Failed to download the usage reports: $($_.Exception.Message)"
    return
}

$mailboxes = Import-Csv $mailboxFile  | Where-Object { $_.'Is Deleted' -ne 'True' }
$oneDrives = Import-Csv $oneDriveFile | Where-Object { $_.'Is Deleted' -ne 'True' }

# Stop if the reports still contain concealed names
if ($mailboxes.Count -gt 0 -and $mailboxes[0].'User Principal Name' -notmatch '@') {
    Write-Warning "The usage reports contain concealed user names. Turn off 'Display concealed user, group, and site names in all reports' in Org settings > Reports and try again."
    return
}

$mailboxLookup = @{}
foreach ($m in $mailboxes) { $mailboxLookup[$m.'User Principal Name'.ToLower()] = $m }

$oneDriveLookup = @{}
foreach ($o in $oneDrives) { $oneDriveLookup[$o.'Owner Principal Name'.ToLower()] = $o }

# 4. Combine everything per user
$report = foreach ($entry in $licensedUsers.Values) {
    $upn      = $entry.User.UserPrincipalName.ToLower()
    $mailbox  = $mailboxLookup[$upn]
    $oneDrive = $oneDriveLookup[$upn]

    $lastActivity = $null
    if ($mailbox -and $mailbox.'Last Activity Date') {
        $lastActivity = [datetime]::ParseExact($mailbox.'Last Activity Date', 'yyyy-MM-dd', [cultureinfo]::InvariantCulture)
    }

    [PSCustomObject]@{
        UserPrincipalName   = $entry.User.UserPrincipalName
        DisplayName         = $entry.User.DisplayName
        AccountEnabled      = $entry.User.AccountEnabled
        License             = $entry.Group
        HasMailbox          = [bool]$mailbox
        MailboxLastActivity = $lastActivity
        MailboxInUse        = [bool]($lastActivity -and $lastActivity -ge $cutoff)
        MailboxGB           = if ($mailbox)  { [math]::Round([double]$mailbox.'Storage Used (Byte)' / 1GB, 2) } else { 0 }
        OneDriveGB          = if ($oneDrive) { [math]::Round([double]$oneDrive.'Storage Used (Byte)' / 1GB, 2) } else { 0 }
    }
}

# 5. Summary per license type
$summary = $report | Group-Object License | ForEach-Object {
    [PSCustomObject]@{
        License      = $_.Name
        Users        = $_.Count
        WithMailbox  = @($_.Group | Where-Object HasMailbox).Count
        MailboxInUse = @($_.Group | Where-Object MailboxInUse).Count
        MailboxTB    = [math]::Round(($_.Group | Measure-Object MailboxGB -Sum).Sum / 1024, 2)
        OneDriveTB   = [math]::Round(($_.Group | Measure-Object OneDriveGB -Sum).Sum / 1024, 2)
    }
}

$summary | Sort-Object License | Format-Table -AutoSize

$needPaid = @($report | Where-Object {
    $_.MailboxInUse -and $_.License -in 'Office 365 A1 (student)', 'Student Use Benefit', 'Exchange Online for Alumni'
}).Count

Write-Host "Mailboxes in use (last $ActiveDays days) on a retiring license: $needPaid" -ForegroundColor Yellow

$report | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
Write-Host "Full report exported to $ExportPath" -ForegroundColor Green