Connect-ExchangeOnline -UserPrincipalName johndoe@contoso.com

$MailboxStorage = Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    $PrimaryStats = Get-MailboxStatistics $_.Identity
    $ArchiveStats = if ($_.ArchiveStatus -eq "Active") { Get-MailboxStatistics -Archive $_.Identity } else { $null }
    [PSCustomObject]@{
        User               = $_.DisplayName
        PrimaryMailboxSize = $PrimaryStats.TotalItemSize.Value.ToString()
        ArchiveMailboxSize = if ($ArchiveStats) { $ArchiveStats.TotalItemSize.Value.ToString() } else { "No Archive" }
        PrimaryItemCount   = $PrimaryStats.ItemCount
        ArchiveItemCount   = if ($ArchiveStats) { $ArchiveStats.ItemCount } else { "No Archive" }
    }
}

$MailboxStorage | Export-Csv -Path "MailboxStorageReport.csv" -NoTypeInformation -Encoding UTF8
