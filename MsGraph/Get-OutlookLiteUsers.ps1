# Install module if needed
# Install-Module Microsoft.Graph -Scope CurrentUser

# Connect to Graph with AuditLog.Read.All and Directory.Read.All
Connect-MgGraph -Scopes "AuditLog.Read.All","Directory.Read.All" -NoWelcome

# Outlook Lite AppId
$outlookLiteAppId = "e9b154d0-7658-433b-bb25-6b8e0a8a7c59"

# Calculate 24 hours ago in UTC
$since = (Get-Date).AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Pull non-interactive sign-ins since $since
$nonInteractive = Get-MgBetaAuditLogSignIn -Filter "(signInEventTypes/any(t: t ne 'interactiveUser')) and createdDateTime ge $since" -Sort "createdDateTime DESC" -All

# Filter locally for Outlook Lite
$outlookLite = $nonInteractive | Where-Object { $_.AppDisplayName -eq "Outlook Lite" }

# Unique users
$outlookLite | Select-Object UserPrincipalName, UserDisplayName -Unique | Sort-Object UserPrincipalName | ft