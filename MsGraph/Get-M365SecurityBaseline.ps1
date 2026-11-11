<#
.SYNOPSIS
    Checks your Microsoft 365 tenant against the LazyAdmin Microsoft 365 Security Checklist.

.DESCRIPTION
    Read-only audit of the 35 items in the LazyAdmin Microsoft 365 security checklist.
    Every result uses the same ID as the article and the Excel checklist (AD-01, EM-02, ...).

    The script only reads settings, it doesn't change anything in your tenant.
    Items that can't be checked with Graph or Exchange Online PowerShell are listed as Manual.

    Output:
    - A summary table in the console
    - An HTML dashboard that you can use as a checklist
    - Two CSV files: one row per check, and one row per affected object

    Article: https://lazyadmin.nl/office-365/best-practice-to-secure-office-365/

.REQUIREMENTS
    - Microsoft.Graph.Authentication module (all Graph calls use Invoke-MgGraphRequest)
    - ExchangeOnlineManagement module (for the EM and MO-01 checks)
    - Global Reader is enough for all checks

.PARAMETER BreakGlassUPN
    The UPNs of your break-glass accounts. Used for AD-01. Without it, AD-01 is reported as Manual.

.PARAMETER SkipExchange
    Skip the Exchange Online checks.

.PARAMETER ExportPath
    Folder for the HTML and CSV reports. Defaults to the current folder.

.EXAMPLE
    .\Get-M365SecurityBaseline.ps1

.EXAMPLE
    .\Get-M365SecurityBaseline.ps1 -BreakGlassUPN "bg01@contoso.onmicrosoft.com","bg02@contoso.onmicrosoft.com" -ExportPath C:\Temp

.NOTES
    Version : 1.1
    Author  : Rudy Mens - LazyAdmin.nl
#>

[CmdletBinding()]
param(
    [string[]]$BreakGlassUPN,
    [switch]$SkipExchange,
    [string]$ExportPath = (Get-Location).Path
)

$articleUrl = 'https://lazyadmin.nl/office-365/best-practice-to-secure-office-365/'

#region Checklist

# Same IDs, names, licenses and priorities as the article and the Excel checklist
$catalog = [ordered]@{
    'AD-01' = @{ Setting = 'Two break-glass accounts'; License = 'Free'; Priority = 'Critical'; Fix = 'Two cloud-only Global Admins with a FIDO2 key each, excluded from all Conditional Access policies' }
    'AD-02' = @{ Setting = 'Limit Global Administrators'; License = 'Free'; Priority = 'Critical'; Fix = 'Keep 2 to 4 Global Administrators, use least-privilege roles for everyone else' }
    'AD-03' = @{ Setting = 'Separate cloud-only admin accounts'; License = 'Free'; Priority = 'Critical'; Fix = 'Use separate admin accounts that are cloud-only and have no license' }
    'AD-04' = @{ Setting = 'Phishing-resistant MFA for admins'; License = 'P1'; Priority = 'Critical'; Fix = 'Conditional Access policy on admin roles with authentication strength Phishing-resistant MFA' }
    'AD-05' = @{ Setting = 'Privileged Identity Management'; License = 'P2'; Priority = 'Recommended'; Fix = 'Make admin roles eligible instead of permanent, activate with MFA' }
    'AD-06' = @{ Setting = 'Restrict access to Entra admin center'; License = 'Free'; Priority = 'Recommended'; Fix = 'Entra ID > Users > User settings: Restrict access to Microsoft Entra admin center = Yes' }
    'SI-01' = @{ Setting = 'MFA for all users'; License = 'Free / P1'; Priority = 'Critical'; Fix = 'Security defaults, or a Conditional Access policy that requires MFA for all users' }
    'SI-02' = @{ Setting = 'Block legacy authentication'; License = 'Free / P1'; Priority = 'Critical'; Fix = 'Security defaults, or a Conditional Access policy that blocks Exchange ActiveSync and Other clients' }
    'SI-03' = @{ Setting = 'Authentication methods policy'; License = 'Free'; Priority = 'Critical'; Fix = 'Enable Microsoft Authenticator, Passkey (FIDO2) and TAP, and complete the migration' }
    'SI-04' = @{ Setting = 'Block device code flow and authentication transfer'; License = 'P1'; Priority = 'Recommended'; Fix = 'Conditional Access policy that blocks both authentication flows' }
    'SI-05' = @{ Setting = 'Disable SMS and voice'; License = 'Free'; Priority = 'Recommended'; Deadline = 'Feb 1, 2027'; Fix = 'Move users to Authenticator or passkeys, then disable SMS and Voice call' }
    'SI-06' = @{ Setting = 'Protect security info registration'; License = 'P1'; Priority = 'Recommended'; Fix = 'Conditional Access policy on the user action Register security information' }
    'SI-07' = @{ Setting = 'Self-service password reset'; License = 'Free / P1'; Priority = 'Recommended'; Fix = 'Enable SSPR for all users, with user and admin notifications' }
    'SI-08' = @{ Setting = 'Password expiration and protection'; License = 'Free / P1'; Priority = 'Recommended'; Fix = 'Set passwords to never expire, add a custom banned password list (P1)' }
    'AP-01' = @{ Setting = 'User consent and admin consent workflow'; License = 'Free'; Priority = 'Critical'; Fix = 'Allow user consent for verified publishers and selected permissions, enable admin consent requests' }
    'AP-02' = @{ Setting = 'Block app registrations and tenant creation'; License = 'Free'; Priority = 'Recommended'; Fix = 'Users can register applications = No, restrict tenant creation = Yes' }
    'AP-03' = @{ Setting = 'Restrict agent blueprint creation'; License = 'Free'; Priority = 'Recommended'; Deadline = 'Since Nov 4, 2026'; Fix = 'Turn it off for default users, assign Agent ID Developer to approved users' }
    'AP-04' = @{ Setting = 'Review existing app consents'; License = 'Free'; Priority = 'Recommended'; Fix = 'Review third-party apps with access to mail or files, remove the ones you do not recognize' }
    'EM-01' = @{ Setting = 'SPF, DKIM and DMARC'; License = 'Free'; Priority = 'Critical'; Fix = 'SPF and DKIM on every domain, DMARC with p=quarantine or p=reject' }
    'EM-02' = @{ Setting = 'Block external auto-forwarding'; License = 'Free'; Priority = 'Critical'; Fix = 'Set Automatic forwarding rules to Off in the default outbound spam policy' }
    'EM-03' = @{ Setting = 'Block shared and resource mailbox sign-in'; License = 'Free'; Priority = 'Critical'; Fix = 'Block sign-in on shared and resource accounts, except Teams Rooms accounts' }
    'EM-04' = @{ Setting = 'Preset security policies'; License = 'Free / Defender P1'; Priority = 'Recommended'; Fix = 'Apply the Standard preset security policy to all recipients' }
    'EM-05' = @{ Setting = 'External email tagging'; License = 'Free'; Priority = 'Recommended'; Fix = 'Set-ExternalInOutlook -Enabled $true' }
    'EM-06' = @{ Setting = 'Disable SMTP AUTH'; License = 'Free'; Priority = 'Recommended'; Deadline = 'End of Dec 2026'; Fix = 'Disable SMTP AUTH tenant-wide, enable it only on mailboxes that still need it' }
    'EM-07' = @{ Setting = 'Disable EWS or use an allow list'; License = 'Free'; Priority = 'Recommended'; Deadline = 'Apr 1, 2027'; Fix = 'Disable EWS, or allow only the applications that still need it' }
    'EM-08' = @{ Setting = 'User reported message settings'; License = 'Free'; Priority = 'Optional'; Fix = 'Send reported messages to Microsoft and your own reporting mailbox' }
    'SH-01' = @{ Setting = 'Limit external sharing'; License = 'Free'; Priority = 'Critical'; Fix = 'New and existing guests, default link type Specific people, guests cannot reshare' }
    'SH-02' = @{ Setting = 'Restrict who can invite guests'; License = 'Free'; Priority = 'Recommended'; Fix = 'Only members and specific admin roles can invite guests, guest access limited' }
    'SH-03' = @{ Setting = 'Third-party and custom apps in Teams'; License = 'Free'; Priority = 'Recommended'; Fix = 'New third-party and custom apps not available by default' }
    'SH-04' = @{ Setting = 'Anonymous users joining meetings'; License = 'Free'; Priority = 'Optional'; Fix = 'Turn off, unless you hold public meetings' }
    'MO-01' = @{ Setting = 'Unified audit log'; License = 'Free'; Priority = 'Critical'; Fix = 'Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true' }
    'MO-02' = @{ Setting = 'Alert policies'; License = 'Free'; Priority = 'Recommended'; Fix = 'Keep the default policies on, and send the alerts to a mailbox that is monitored' }
    'MO-03' = @{ Setting = 'Secure Score and Baseline Security Mode'; License = 'Free'; Priority = 'Recommended'; Fix = 'Review Secure Score and Baseline Security Mode every month' }
    'MO-04' = @{ Setting = 'Backup'; License = 'Third-party'; Priority = 'Recommended'; Fix = 'Back up SharePoint, OneDrive and Exchange, and export your Conditional Access policies' }
    'MO-05' = @{ Setting = 'Company branding'; License = 'Free'; Priority = 'Optional'; Fix = 'Add your logo and background to the sign-in page' }
}

$areas = [ordered]@{
    'AD' = 'Admin accounts'
    'SI' = 'Sign-in and authentication'
    'AP' = 'Apps and consent'
    'EM' = 'Email'
    'SH' = 'Sharing and collaboration'
    'MO' = 'Monitoring and recovery'
}

#endregion

#region Helpers

$script:results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Id,
        [ValidateSet('Pass', 'Warn', 'Fail', 'Info', 'Manual', 'Error')]
        [string]$Status,
        [string]$Summary,
        [object[]]$Items = @()
    )
    $entry = $catalog[$Id]
    $script:results.Add([PSCustomObject]@{
        Id       = $Id
        Area     = $areas[$Id.Substring(0, 2)]
        Setting  = $entry.Setting
        Priority = $entry.Priority
        License  = $entry.License
        Deadline = $entry.Deadline
        Status   = $Status
        Summary  = $Summary
        Items    = @($Items)
        Fix      = $entry.Fix
    })
}

function New-ResultItem {
    # An affected object, shown in the details of a check
    param([string]$Object, [string]$Detail)
    [PSCustomObject]@{ Object = $Object; Detail = $Detail }
}

function Invoke-Check {
    # Runs a check and reports an Error result instead of stopping the script
    param([string]$Id, [scriptblock]$Check)
    try {
        & $Check
    }
    catch {
        Add-Result -Id $Id -Status Error -Summary $_.Exception.Message
    }
}

function Get-Graph {
    # GET request with paging. Returns the value collection, or the object itself
    param([string]$Uri)

    $items = @()
    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        if ($null -ne $response.PSObject.Properties['value']) {
            $items += $response.value
            $Uri = $response.'@odata.nextLink'
        }
        else {
            return $response
        }
    } while ($Uri)

    return $items
}

#endregion

#region Connect

$scopes = @(
    'Policy.Read.All',
    'Directory.Read.All',
    'RoleManagement.Read.Directory',
    'UserAuthenticationMethod.Read.All',
    'AuditLog.Read.All',
    'SharePointTenantSettings.Read.All',
    'SecurityEvents.Read.All'
)

Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
Connect-MgGraph -Scopes $scopes -NoWelcome

if (-not $SkipExchange) {
    Write-Host "Connecting to Exchange Online..." -ForegroundColor Cyan
    Connect-ExchangeOnline -ShowBanner:$false
}

#endregion

#region Shared data

Write-Host "Reading tenant settings..." -ForegroundColor Cyan

$org              = @(Get-Graph "https://graph.microsoft.com/v1.0/organization")[0]
$tenantName       = $org.displayName
$tenantDomain     = ($org.verifiedDomains | Where-Object { $_.isDefault }).name
$securityDefaults = (Get-Graph "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy").isEnabled
$authzPolicy      = Get-Graph "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"
$authMethods      = Get-Graph "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy"

# Conditional Access requires P1. Without it the list is empty or the call fails
try {
    $caPolicies = @(Get-Graph "https://graph.microsoft.com/beta/identity/conditionalAccess/policies")
}
catch {
    $caPolicies = @()
    Write-Host "Could not read Conditional Access policies: $($_.Exception.Message)" -ForegroundColor Yellow
}

$caEnabled    = @($caPolicies | Where-Object { $_.state -eq 'enabled' })
$caReportOnly = @($caPolicies | Where-Object { $_.state -eq 'enabledForReportingButNotEnforced' })

function Get-MethodState([string]$MethodId) {
    ($authMethods.authenticationMethodConfigurations | Where-Object { $_.id -eq $MethodId }).state
}

# Role template IDs
$globalAdminRoleId = '62e90394-69f5-4237-9190-012177145e10'
$privilegedRoles = @(
    '62e90394-69f5-4237-9190-012177145e10', # Global Administrator
    'e8611ab8-c189-46e8-94e1-60213ab1f814', # Privileged Role Administrator
    '7be44c8a-adaf-4e2a-84d6-ab2649e08a13', # Privileged Authentication Administrator
    '194ae4cb-b126-40b2-bd5b-6091b380977d', # Security Administrator
    'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9', # Conditional Access Administrator
    '29232cdf-9323-42fd-ade2-1d097af3e4de', # Exchange Administrator
    'f28a1f50-f6e7-4571-818b-6a12f2af6b6c', # SharePoint Administrator
    'fe930be7-5e62-47db-91af-98c3a49a38b1', # User Administrator
    '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3', # Application Administrator
    '158c047a-c907-4556-b7ef-446551a6b5f7', # Cloud Application Administrator
    'c4e39bd9-1100-46d3-8c65-fb160da0071f', # Authentication Administrator
    '729827e3-9c14-49f7-bb1b-9608f156bbb8', # Helpdesk Administrator
    '3a2c62db-5318-420d-8d74-23affee5d9d5'  # Intune Administrator
)

$roleAssignments = @(Get-Graph "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$expand=principal")

# Role names, so we can show which roles an admin has
$roleNames = @{}
Get-Graph "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$select=id,displayName" |
    ForEach-Object { $roleNames[$_.id] = $_.displayName }

#endregion

#region Admin accounts

Write-Host "Checking admin accounts..." -ForegroundColor Cyan

Invoke-Check 'AD-01' {
    if (-not $BreakGlassUPN) {
        Add-Result 'AD-01' Manual 'Run the script with -BreakGlassUPN to check the FIDO2 keys and CA exclusions'
        return
    }

    $items = @()
    if ($BreakGlassUPN.Count -lt 2) { $items += New-ResultItem 'Break-glass accounts' "Only $($BreakGlassUPN.Count) account specified" }

    foreach ($upn in $BreakGlassUPN) {
        $user = Get-Graph "https://graph.microsoft.com/v1.0/users/$upn`?`$select=id,userPrincipalName"
        $keys = @(Get-Graph "https://graph.microsoft.com/v1.0/users/$($user.id)/authentication/fido2Methods")
        if ($keys.Count -eq 0) { $items += New-ResultItem $upn 'No FIDO2 key registered' }

        # Every enabled CA policy should exclude the account
        foreach ($policy in ($caEnabled | Where-Object { $_.conditions.users.excludeUsers -notcontains $user.id })) {
            $items += New-ResultItem $upn "Not excluded from CA policy: $($policy.displayName)"
        }
    }

    if ($items) { Add-Result 'AD-01' Warn "$($items.Count) issues found on the break-glass accounts" $items }
    else { Add-Result 'AD-01' Pass "$($BreakGlassUPN.Count) accounts with FIDO2 keys, excluded from all enabled CA policies" }
}

Invoke-Check 'AD-02' {
    $gaAssignments = @($roleAssignments | Where-Object { $_.roleDefinitionId -eq $globalAdminRoleId })
    $items = $gaAssignments | ForEach-Object {
        $name = if ($_.principal.userPrincipalName) { $_.principal.userPrincipalName } else { $_.principal.displayName }
        New-ResultItem $name ($_.principal.'@odata.type' -replace '#microsoft.graph.', '')
    }

    $count = $gaAssignments.Count
    if ($count -ge 2 -and $count -le 4) { $status = 'Pass' } else { $status = 'Warn' }
    Add-Result 'AD-02' $status "$count active Global Administrators (recommended: 2 to 4)" $items
}

Invoke-Check 'AD-03' {
    $adminAssignments = $roleAssignments |
        Where-Object { $_.roleDefinitionId -in $privilegedRoles -and $_.principal.'@odata.type' -eq '#microsoft.graph.user' }

    $admins = $adminAssignments | Group-Object principalId

    $items = foreach ($admin in $admins) {
        $u = Get-Graph "https://graph.microsoft.com/v1.0/users/$($admin.Name)?`$select=userPrincipalName,onPremisesSyncEnabled,assignedLicenses"

        $reasons = @()
        if ($u.onPremisesSyncEnabled) { $reasons += 'Synced from AD' }
        if (@($u.assignedLicenses).Count -gt 0) { $reasons += 'Licensed' }

        if ($reasons) {
            $roles = ($admin.Group.roleDefinitionId | ForEach-Object { $roleNames[$_] }) -join ', '
            New-ResultItem $u.userPrincipalName "$($reasons -join ', ')  |  $roles"
        }
    }

    $total = @($admins).Count
    if ($items) { Add-Result 'AD-03' Warn "$(@($items).Count) of $total privileged accounts are synced or licensed" $items }
    else { Add-Result 'AD-03' Pass "All $total privileged accounts are cloud-only without a license" }
}

Invoke-Check 'AD-04' {
    # 00000000-0000-0000-0000-000000000004 is the built-in Phishing-resistant MFA strength
    $isPhishingResistant = {
        @($_.conditions.users.includeRoles).Count -gt 0 -and
        $_.grantControls.authenticationStrength.id -eq '00000000-0000-0000-0000-000000000004'
    }

    $enabled    = @($caEnabled | Where-Object $isPhishingResistant)
    $reportOnly = @($caReportOnly | Where-Object $isPhishingResistant)

    if ($enabled) { Add-Result 'AD-04' Pass "Enforced by: $(($enabled.displayName) -join ', ')" }
    elseif ($reportOnly) { Add-Result 'AD-04' Warn "Policy is in report-only mode: $(($reportOnly.displayName) -join ', ')" }
    else { Add-Result 'AD-04' Fail 'No Conditional Access policy requires phishing-resistant MFA for admin roles' }
}

Invoke-Check 'AD-05' {
    try {
        $eligible = @(Get-Graph "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilitySchedules")
    }
    catch {
        Add-Result 'AD-05' Info 'PIM is not available, it requires Entra ID P2'
        return
    }

    if ($eligible.Count -gt 0) { Add-Result 'AD-05' Pass "$($eligible.Count) eligible role assignments" }
    else { Add-Result 'AD-05' Warn 'No eligible role assignments, all admin roles are permanent' }
}

Add-Result 'AD-06' Manual 'Not available in Graph. Check Entra ID > Users > User settings'

#endregion

#region Sign-in and authentication

Write-Host "Checking sign-in and authentication..." -ForegroundColor Cyan

Invoke-Check 'SI-01' {
    $mfaPolicy = @($caEnabled | Where-Object {
        $_.conditions.users.includeUsers -contains 'All' -and
        $_.conditions.applications.includeApplications -contains 'All' -and
        ($_.grantControls.builtInControls -contains 'mfa' -or $_.grantControls.authenticationStrength)
    })

    # Users that haven't registered an MFA method yet. This report may require P1
    $items = @()
    $extra = ''
    try {
        $notCapable = @(Get-Graph "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails?`$filter=isMfaCapable eq false and userType eq 'member'")
        $items = $notCapable | ForEach-Object { New-ResultItem $_.userPrincipalName 'No MFA method registered' }
        $extra = ", $($notCapable.Count) users without an MFA method"
    }
    catch { }

    if ($securityDefaults) { Add-Result 'SI-01' Pass "Security defaults enabled$extra" $items }
    elseif ($mfaPolicy) { Add-Result 'SI-01' Pass "Enforced by: $(($mfaPolicy.displayName) -join ', ')$extra" $items }
    else { Add-Result 'SI-01' Fail "No security defaults and no Conditional Access policy that requires MFA for all users$extra" $items }
}

Invoke-Check 'SI-02' {
    $isLegacyBlock = {
        ($_.conditions.clientAppTypes -contains 'other' -or $_.conditions.clientAppTypes -contains 'exchangeActiveSync') -and
        $_.grantControls.builtInControls -contains 'block'
    }
    $enabled    = @($caEnabled | Where-Object $isLegacyBlock)
    $reportOnly = @($caReportOnly | Where-Object $isLegacyBlock)

    if ($securityDefaults) { Add-Result 'SI-02' Pass 'Blocked by security defaults' }
    elseif ($enabled) { Add-Result 'SI-02' Pass "Enforced by: $(($enabled.displayName) -join ', ')" }
    elseif ($reportOnly) { Add-Result 'SI-02' Warn "Policy is in report-only mode: $(($reportOnly.displayName) -join ', ')" }
    else { Add-Result 'SI-02' Fail 'Legacy authentication is not blocked' }
}

Invoke-Check 'SI-03' {
    $migration = $authMethods.policyMigrationState
    $methods = [ordered]@{
        'Microsoft Authenticator' = Get-MethodState 'MicrosoftAuthenticator'
        'Passkey (FIDO2)'         = Get-MethodState 'Fido2'
        'Temporary Access Pass'   = Get-MethodState 'TemporaryAccessPass'
    }

    $items = @(New-ResultItem 'Migration state' $migration)
    $items += $methods.Keys | ForEach-Object { New-ResultItem $_ $methods[$_] }

    if ($migration -eq 'migrationComplete' -and $methods['Microsoft Authenticator'] -eq 'enabled' -and $methods['Passkey (FIDO2)'] -eq 'enabled') {
        Add-Result 'SI-03' Pass 'Migration complete, Authenticator and passkeys enabled' $items
    }
    else { Add-Result 'SI-03' Warn 'Migration not complete, or Authenticator or passkeys not enabled' $items }
}

Invoke-Check 'SI-04' {
    $flowPolicies = @($caEnabled | Where-Object {
        $_.conditions.authenticationFlows.transferMethods -and
        $_.grantControls.builtInControls -contains 'block'
    })
    $methods = ($flowPolicies.conditions.authenticationFlows.transferMethods) -join ','

    $deviceCode = $methods -match 'deviceCodeFlow'
    $transfer   = $methods -match 'authenticationTransfer'

    if ($deviceCode -and $transfer) { Add-Result 'SI-04' Pass "Both flows blocked by: $(($flowPolicies.displayName) -join ', ')" }
    elseif ($deviceCode) { Add-Result 'SI-04' Warn 'Device code flow is blocked, authentication transfer is not' }
    elseif ($transfer) { Add-Result 'SI-04' Warn 'Authentication transfer is blocked, device code flow is not' }
    else { Add-Result 'SI-04' Fail 'No Conditional Access policy blocks these authentication flows' }
}

Invoke-Check 'SI-05' {
    $sms   = Get-MethodState 'Sms'
    $voice = Get-MethodState 'Voice'
    $items = @((New-ResultItem 'SMS' $sms), (New-ResultItem 'Voice call' $voice))

    if ($sms -eq 'disabled' -and $voice -eq 'disabled') { Add-Result 'SI-05' Pass 'SMS and voice are disabled' $items }
    else { Add-Result 'SI-05' Warn 'SMS or voice is still enabled. Microsoft-provided SMS and voice retire on Feb 1, 2027' $items }
}

Invoke-Check 'SI-06' {
    $regPolicy = @($caEnabled | Where-Object { $_.conditions.applications.includeUserActions -contains 'urn:user:registersecurityinfo' })

    if ($regPolicy) { Add-Result 'SI-06' Pass "Enforced by: $(($regPolicy.displayName) -join ', ')" }
    else { Add-Result 'SI-06' Fail 'No Conditional Access policy on Register security information' }
}

Add-Result 'SI-07' Manual 'Not available in Graph. Check Entra ID > Password reset > Properties and Notifications'

Invoke-Check 'SI-08' {
    $domains = @(Get-Graph "https://graph.microsoft.com/v1.0/domains") |
        Where-Object { $_.isVerified -and $_.authenticationType -eq 'Managed' }

    # 2147483647 means passwords never expire
    $items = foreach ($domain in $domains) {
        if ($domain.passwordValidityPeriodInDays -eq 2147483647) { New-ResultItem $domain.id 'Passwords never expire' }
        else { New-ResultItem $domain.id "Passwords expire after $($domain.passwordValidityPeriodInDays) days" }
    }
    $expiring = @($domains | Where-Object { $_.passwordValidityPeriodInDays -ne 2147483647 })

    # Custom banned password list, stored in the Password Rule Settings
    $banned = 'custom banned password list not configured'
    try {
        $pwSettings = @(Get-Graph "https://graph.microsoft.com/v1.0/groupSettings") | Where-Object { $_.displayName -eq 'Password Rule Settings' }
        if (($pwSettings.values | Where-Object { $_.name -eq 'EnableBannedPasswordCheck' }).value -eq 'True') {
            $banned = 'custom banned password list enabled'
        }
    }
    catch { $banned = 'custom banned password list could not be read' }

    if ($expiring) { Add-Result 'SI-08' Warn "Passwords expire on $($expiring.Count) domain(s), $banned" $items }
    else { Add-Result 'SI-08' Pass "Passwords never expire, $banned" $items }
}

#endregion

#region Apps and consent

Write-Host "Checking apps and consent..." -ForegroundColor Cyan

Invoke-Check 'AP-01' {
    $consent = @($authzPolicy.defaultUserRolePermissions.permissionGrantPoliciesAssigned) |
        Where-Object { $_ -like 'ManagePermissionGrantsForSelf.*' }
    $policy = ($consent -replace 'ManagePermissionGrantsForSelf\.', '') -join ', '

    $workflow = (Get-Graph "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy").isEnabled

    switch -Wildcard ($policy) {
        ''                                     { $status = 'Pass'; $text = 'User consent disabled' }
        '*microsoft-user-default-low*'         { $status = 'Pass'; $text = 'Verified publishers, selected permissions' }
        '*microsoft-user-default-recommended*' { $status = 'Warn'; $text = 'Microsoft-managed consent settings' }
        '*microsoft-user-default-legacy*'      { $status = 'Fail'; $text = 'Users can consent to all apps' }
        default                                { $status = 'Info'; $text = "Custom consent policy: $policy" }
    }

    $items = @((New-ResultItem 'User consent policy' $(if ($policy) { $policy } else { 'none' })), (New-ResultItem 'Admin consent workflow' $(if ($workflow) { 'Enabled' } else { 'Disabled' })))

    if ($workflow) { $text += ', admin consent workflow enabled' }
    else {
        $text += ', admin consent workflow disabled'
        if ($status -eq 'Pass') { $status = 'Warn' }
    }

    Add-Result 'AP-01' $status $text $items
}

Invoke-Check 'AP-02' {
    $perm = $authzPolicy.defaultUserRolePermissions
    $items = @((New-ResultItem 'Users can register applications' $perm.allowedToCreateApps), (New-ResultItem 'Users can create tenants' $perm.allowedToCreateTenants))

    if (-not $perm.allowedToCreateApps -and -not $perm.allowedToCreateTenants) { Add-Result 'AP-02' Pass 'Users cannot register apps or create tenants' $items }
    else { Add-Result 'AP-02' Warn 'Users can still register apps or create tenants' $items }
}

Add-Result 'AP-03' Manual 'Check the agent blueprint setting in the Entra admin center'

Invoke-Check 'AP-04' {
    $riskyScopes = 'Mail.Read', 'Mail.ReadWrite', 'Mail.Send', 'Files.Read.All', 'Files.ReadWrite.All',
                   'Sites.Read.All', 'Sites.ReadWrite.All', 'Chat.Read', 'Chat.ReadWrite', 'Contacts.ReadWrite',
                   'Calendars.ReadWrite', 'Notes.ReadWrite.All', 'Directory.ReadWrite.All'

    # Microsoft first-party apps are owned by these tenants
    $microsoftTenants = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a', '72f988bf-86f1-41af-91ab-2d7cd011db47'

    $grants = @(Get-Graph "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?`$filter=consentType eq 'Principal'")

    $items = foreach ($group in ($grants | Group-Object clientId)) {
        $scopes = ($group.Group.scope -join ' ').Split(' ', [StringSplitOptions]::RemoveEmptyEntries) | Select-Object -Unique
        $risky = $scopes | Where-Object { $_ -in $riskyScopes }
        if (-not $risky) { continue }

        $sp = Get-Graph "https://graph.microsoft.com/v1.0/servicePrincipals/$($group.Name)?`$select=displayName,appOwnerOrganizationId"
        if ($sp.appOwnerOrganizationId -in $microsoftTenants) { continue }

        New-ResultItem $sp.displayName "$($group.Count) user(s)  |  $($risky -join ', ')"
    }

    if ($items) { Add-Result 'AP-04' Warn "$(@($items).Count) third-party app(s) with user-granted access to mail or files" $items }
    else { Add-Result 'AP-04' Pass 'No third-party apps with user-granted access to mail or files' }
}

#endregion

#region Email

$exchangeIds = 'EM-01', 'EM-02', 'EM-03', 'EM-04', 'EM-05', 'EM-06', 'EM-07', 'EM-08', 'MO-01'

if (-not $SkipExchange) {

    Write-Host "Checking Exchange Online..." -ForegroundColor Cyan

    Invoke-Check 'EM-01' {
        $domains = @(Get-AcceptedDomain | Where-Object { $_.DomainName -notlike '*.onmicrosoft.com' })

        if ($domains.Count -eq 0) {
            Add-Result 'EM-01' Info 'No custom domains, only the onmicrosoft.com domain is used'
            return
        }

        $dkim   = Get-DkimSigningConfig
        $hasDns = [bool](Get-Command Resolve-DnsName -ErrorAction SilentlyContinue)
        $items  = @()
        $issues = 0

        foreach ($domain in $domains.DomainName) {
            $result = @()

            $config = $dkim | Where-Object { $_.Domain -eq $domain }
            if ($config.Enabled) { $result += 'DKIM enabled' } else { $result += 'DKIM disabled'; $issues++ }

            # DNS checks need Resolve-DnsName, which is only available on Windows
            if ($hasDns) {
                $spf = Resolve-DnsName -Name $domain -Type TXT -ErrorAction SilentlyContinue | Where-Object { $_.Strings -match '^v=spf1' }
                if ($spf) { $result += 'SPF found' } else { $result += 'No SPF'; $issues++ }

                $dmarc = (Resolve-DnsName -Name "_dmarc.$domain" -Type TXT -ErrorAction SilentlyContinue).Strings -join ''
                if (-not $dmarc) { $result += 'No DMARC'; $issues++ }
                elseif ($dmarc -match 'p=(\w+)') {
                    $result += "DMARC p=$($Matches[1])"
                    if ($Matches[1] -eq 'none') { $issues++ }
                }
            }

            $items += New-ResultItem $domain ($result -join ', ')
        }

        $note = if ($hasDns) { '' } else { ' (SPF and DMARC not checked, Resolve-DnsName is only available on Windows)' }

        if ($issues) { Add-Result 'EM-01' Warn "$issues issue(s) on $($domains.Count) domain(s)$note" $items }
        else { Add-Result 'EM-01' Pass "$($domains.Count) domain(s) checked$note" $items }
    }

    Invoke-Check 'EM-02' {
        $default = Get-HostedOutboundSpamFilterPolicy -Identity Default
        $allowed = @(Get-HostedOutboundSpamFilterPolicy | Where-Object { $_.AutoForwardingMode -eq 'On' -and -not $_.IsDefault })
        $forwarding = @(Get-EXOMailbox -ResultSize Unlimited -Filter "ForwardingSmtpAddress -ne `$null" -Properties ForwardingSmtpAddress)

        $items = @()
        $items += $allowed | ForEach-Object { New-ResultItem $_.Name 'Custom outbound policy that allows forwarding' }
        $items += $forwarding | ForEach-Object { New-ResultItem $_.UserPrincipalName "Forwards to $($_.ForwardingSmtpAddress -replace '^smtp:', '')" }

        $summary = "Default policy: $($default.AutoForwardingMode), $($allowed.Count) custom policies allow forwarding, $($forwarding.Count) mailboxes with a forwarding address"

        switch ($default.AutoForwardingMode) {
            'Off'       { Add-Result 'EM-02' Pass $summary $items }
            'Automatic' { Add-Result 'EM-02' Warn "$summary. Set it explicitly to Off" $items }
            default     { Add-Result 'EM-02' Fail $summary $items }
        }
    }

    Invoke-Check 'EM-03' {
        $mailboxes = @(Get-EXOMailbox -RecipientTypeDetails SharedMailbox, RoomMailbox, EquipmentMailbox -ResultSize Unlimited)
        $ids = @($mailboxes.ExternalDirectoryObjectId | Where-Object { $_ })

        # Check the accounts in batches of 15 with a server-side filter
        $enabled = for ($i = 0; $i -lt $ids.Count; $i += 15) {
            $batch = ($ids[$i..([Math]::Min($i + 14, $ids.Count - 1))] | ForEach-Object { "'$_'" }) -join ','
            Get-Graph "https://graph.microsoft.com/v1.0/users?`$filter=id in ($batch)&`$select=id,userPrincipalName,accountEnabled" |
                Where-Object { $_.accountEnabled }
        }

        $items = foreach ($account in $enabled) {
            $type = ($mailboxes | Where-Object { $_.ExternalDirectoryObjectId -eq $account.id }).RecipientTypeDetails
            New-ResultItem $account.userPrincipalName "$type, sign-in allowed"
        }

        if ($items) { Add-Result 'EM-03' Fail "$(@($items).Count) of $($ids.Count) accounts can sign in. Exclude Teams Rooms accounts" $items }
        else { Add-Result 'EM-03' Pass "All $($ids.Count) shared and resource accounts are blocked" }
    }

    Invoke-Check 'EM-04' {
        $rules = @(Get-EOPProtectionPolicyRule -ErrorAction SilentlyContinue)
        $items = $rules | ForEach-Object { New-ResultItem $_.Name $_.State }
        $enabled = @($rules | Where-Object { $_.State -eq 'Enabled' })

        if ($enabled) { Add-Result 'EM-04' Pass "Enabled: $(($enabled.Name) -join ', ')" $items }
        else { Add-Result 'EM-04' Fail 'No preset security policy enabled' $items }
    }

    Invoke-Check 'EM-05' {
        if ((Get-ExternalInOutlook).Enabled) { Add-Result 'EM-05' Pass 'External email tagging is enabled' }
        else { Add-Result 'EM-05' Fail 'External email tagging is disabled' }
    }

    Invoke-Check 'EM-06' {
        $disabled = (Get-TransportConfig).SmtpClientAuthenticationDisabled

        # SmtpClientAuthenticationDisabled is not a filterable property, so we filter client-side.
        # $false means SMTP AUTH is explicitly enabled on the mailbox, $null follows the tenant setting
        $exceptions = @(Get-EXOCasMailbox -ResultSize Unlimited -Properties SmtpClientAuthenticationDisabled |
            Where-Object { $_.SmtpClientAuthenticationDisabled -eq $false })

        $items = $exceptions | ForEach-Object { New-ResultItem $_.PrimarySmtpAddress 'SMTP AUTH explicitly enabled' }

        if ($disabled) { Add-Result 'EM-06' Pass "Disabled tenant-wide, $($exceptions.Count) mailbox(es) with an exception" $items }
        else { Add-Result 'EM-06' Warn "Enabled tenant-wide, $($exceptions.Count) mailbox(es) explicitly enabled. Disabled by default end of Dec 2026" $items }
    }

    Invoke-Check 'EM-07' {
        $orgConfig = Get-OrganizationConfig

        if ($orgConfig.EwsEnabled -eq $false) { Add-Result 'EM-07' Pass 'EWS is disabled' }
        elseif ($orgConfig.EwsEnabled -eq $true) {
            $policy = if ($orgConfig.EwsApplicationAccessPolicy) { ", access policy: $($orgConfig.EwsApplicationAccessPolicy)" } else { ', no allow list configured' }
            Add-Result 'EM-07' Warn "EWS is enabled$policy. EWS is turned off permanently on Apr 1, 2027"
        }
        else { Add-Result 'EM-07' Warn 'EWS is not configured (default). Check the EWS usage report in the Microsoft 365 admin center' }
    }

    Invoke-Check 'EM-08' {
        $report = Get-ReportSubmissionPolicy

        if ($report.ReportPhishToCustomizedAddress -or $report.ReportJunkToCustomizedAddress) {
            Add-Result 'EM-08' Pass "Reported messages also go to: $($report.ReportPhishAddresses -join ', ')"
        }
        else { Add-Result 'EM-08' Warn 'Reported messages only go to Microsoft' }
    }

    Invoke-Check 'MO-01' {
        if ((Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled) { Add-Result 'MO-01' Pass 'Unified audit log is enabled' }
        else { Add-Result 'MO-01' Fail 'Unified audit log is disabled' }
    }
}
else {
    foreach ($id in $exchangeIds) { Add-Result $id Manual 'Skipped with -SkipExchange' }
}

#endregion

#region Sharing and collaboration

Write-Host "Checking sharing settings..." -ForegroundColor Cyan

Invoke-Check 'SH-01' {
    $spo = Get-Graph "https://graph.microsoft.com/v1.0/admin/sharepoint/settings"
    $items = @((New-ResultItem 'Sharing capability' $spo.sharingCapability), (New-ResultItem 'Guests can reshare items' $spo.isResharingByExternalUsersEnabled))

    if ($spo.sharingCapability -eq 'externalUserAndGuestSharing') { Add-Result 'SH-01' Fail 'Anyone links are allowed' $items }
    elseif ($spo.isResharingByExternalUsersEnabled) { Add-Result 'SH-01' Warn 'Guests can reshare items they do not own' $items }
    else { Add-Result 'SH-01' Pass "Sharing limited to $($spo.sharingCapability)" $items }
}

Invoke-Check 'SH-02' {
    $guestRoles = @{
        'a0b1b346-4d3e-4e8b-98f8-753987be4970' = 'Same as members'
        '10dae51f-b6af-4016-8d66-8c2a99b929b3' = 'Limited'
        '2af84b1e-32c8-42b7-82bc-daa82404023b' = 'Restricted'
    }
    $guestAccess = $guestRoles[$authzPolicy.guestUserRoleId]
    $items = @((New-ResultItem 'Guest invites allowed from' $authzPolicy.allowInvitesFrom), (New-ResultItem 'Guest user access' $guestAccess))

    if ($authzPolicy.allowInvitesFrom -eq 'everyone') { Add-Result 'SH-02' Fail 'Everyone, including guests, can invite guests' $items }
    elseif ($guestAccess -eq 'Same as members') { Add-Result 'SH-02' Fail 'Guests have the same access as members' $items }
    else { Add-Result 'SH-02' Pass "Invites from $($authzPolicy.allowInvitesFrom), guest access $($guestAccess.ToLower())" $items }
}

Add-Result 'SH-03' Manual 'Check Teams admin center > Teams apps > Manage apps > Org-wide app settings'
Add-Result 'SH-04' Manual 'Check Teams admin center > Meetings > Meeting settings'

#endregion

#region Monitoring and recovery

Write-Host "Checking monitoring..." -ForegroundColor Cyan

Add-Result 'MO-02' Manual 'Check Defender portal > Policies & rules > Alert policy, and who receives the alerts'

$secureScore = $null
Invoke-Check 'MO-03' {
    # Direct call, so we don't page through the whole score history
    $score = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/security/secureScores?`$top=1" -OutputType PSObject).value[0]
    $percentage = [Math]::Round(($score.currentScore / $score.maxScore) * 100)
    $script:secureScore = @{ Current = [Math]::Round($score.currentScore); Max = [Math]::Round($score.maxScore); Percentage = $percentage }

    Add-Result 'MO-03' Info "Secure Score $([Math]::Round($score.currentScore)) of $([Math]::Round($score.maxScore)) ($percentage%). Also review Baseline Security Mode"
}

Add-Result 'MO-04' Manual 'Verify your backup for SharePoint, OneDrive and Exchange'

Invoke-Check 'MO-05' {
    try {
        $branding = Get-Graph "https://graph.microsoft.com/v1.0/organization/$($org.id)/branding"
    }
    catch {
        Add-Result 'MO-05' Warn 'No company branding configured'
        return
    }

    if ($branding.bannerLogoRelativeUrl -or $branding.backgroundImageRelativeUrl -or $branding.squareLogoRelativeUrl) {
        Add-Result 'MO-05' Pass 'Custom branding is configured'
    }
    else { Add-Result 'MO-05' Warn 'No logo or background configured' }
}

#endregion

#region Console output

$sorted = foreach ($id in $catalog.Keys) { $script:results | Where-Object { $_.Id -eq $id } | Select-Object -First 1 }

$colors = @{ Pass = 'Green'; Warn = 'Yellow'; Fail = 'Red'; Info = 'Cyan'; Manual = 'DarkGray'; Error = 'Magenta' }

try { $width = $Host.UI.RawUI.WindowSize.Width } catch { $width = 160 }
if (-not $width -or $width -lt 100) { $width = 160 }
$summaryWidth = $width - 66

Write-Host ""
Write-Host ("  {0,-7}{1,-8}{2,-50}{3}" -f 'ID', 'Status', 'Setting', 'Result') -ForegroundColor White
Write-Host ("  " + ('-' * ($width - 4))) -ForegroundColor DarkGray

foreach ($area in $areas.Keys) {
    Write-Host ""
    Write-Host "  $($areas[$area])" -ForegroundColor Cyan

    foreach ($r in ($sorted | Where-Object { $_.Id.StartsWith($area) })) {
        $summary = $r.Summary
        if ($summary.Length -gt $summaryWidth) { $summary = $summary.Substring(0, $summaryWidth - 3) + '...' }

        $setting = $r.Setting
        if ($setting.Length -gt 48) { $setting = $setting.Substring(0, 45) + '...' }

        Write-Host ("  {0,-7}" -f $r.Id) -NoNewline
        Write-Host ("{0,-8}" -f $r.Status) -ForegroundColor $colors[$r.Status] -NoNewline
        Write-Host ("{0,-50}" -f $setting) -NoNewline
        Write-Host $summary -ForegroundColor Gray
    }
}

$counts = $sorted | Group-Object Status -AsHashTable -AsString
function Get-Count([string]$Status) { if ($counts -and $counts[$Status]) { @($counts[$Status]).Count } else { 0 } }

Write-Host ""
Write-Host ("  " + ('-' * ($width - 4))) -ForegroundColor DarkGray
Write-Host "  " -NoNewline
foreach ($s in 'Pass', 'Warn', 'Fail', 'Error', 'Info', 'Manual') {
    Write-Host ("{0}: {1}   " -f $s, (Get-Count $s)) -ForegroundColor $colors[$s] -NoNewline
}
Write-Host ""

$criticalFails = @($sorted | Where-Object { $_.Status -eq 'Fail' -and $_.Priority -eq 'Critical' })
if ($criticalFails) {
    Write-Host ""
    Write-Host "  Critical items to fix first:" -ForegroundColor Red
    foreach ($r in $criticalFails) { Write-Host "  - $($r.Id) $($r.Setting)" -ForegroundColor Red }
}

#endregion

#region CSV export

$stamp   = Get-Date -Format 'yyyy-MM-dd_HHmm'
$csv     = Join-Path $ExportPath "M365-SecurityBaseline-$stamp.csv"
$csvItem = Join-Path $ExportPath "M365-SecurityBaseline-$stamp-details.csv"
$html    = Join-Path $ExportPath "M365-SecurityBaseline-$stamp.html"

# -UseCulture uses the list separator of your system, so Excel opens the file in columns.
# Excel needs a BOM to read UTF-8 correctly, PowerShell 7 only adds it with utf8BOM
$encoding = if ($PSVersionTable.PSVersion.Major -ge 6) { 'utf8BOM' } else { 'UTF8' }

$sorted | Select-Object Id, Area, Setting, Priority, License, Deadline, Status, Summary, @{ n = 'AffectedObjects'; e = { $_.Items.Count } }, Fix |
    Export-Csv -Path $csv -NoTypeInformation -Encoding $encoding -UseCulture

$detailRows = foreach ($r in $sorted) {
    foreach ($item in $r.Items) {
        [PSCustomObject]@{ Id = $r.Id; Setting = $r.Setting; Status = $r.Status; Object = $item.Object; Detail = $item.Detail }
    }
}
if ($detailRows) { $detailRows | Export-Csv -Path $csvItem -NoTypeInformation -Encoding $encoding -UseCulture }

#endregion

#region HTML dashboard

function Get-HtmlText([object]$Text) { [System.Net.WebUtility]::HtmlEncode([string]$Text) }

$pass   = Get-Count 'Pass'
$warn   = Get-Count 'Warn'
$fail   = Get-Count 'Fail'
$errors = Get-Count 'Error'
$checked = $pass + $warn + $fail + $errors
$passPct = if ($checked) { [Math]::Round(($pass / $checked) * 100) } else { 0 }

function Get-BarWidth([int]$n) { if ($checked) { [Math]::Round(($n / $checked) * 100, 2) } else { 0 } }

$sections = foreach ($area in $areas.Keys) {
    $areaResults = @($sorted | Where-Object { $_.Id.StartsWith($area) })
    $areaPass = @($areaResults | Where-Object Status -eq 'Pass').Count
    $areaChecked = @($areaResults | Where-Object { $_.Status -in 'Pass', 'Warn', 'Fail', 'Error' }).Count

    $rows = foreach ($r in $areaResults) {
        $deadline = if ($r.Deadline) { "<span class='badge deadline'>$(Get-HtmlText $r.Deadline)</span>" } else { '' }
        $count = if ($r.Items.Count) { "<span class='count'>$($r.Items.Count)</span>" } else { '' }

        $itemTable = ''
        if ($r.Items.Count) {
            $itemRows = ($r.Items | ForEach-Object { "<tr><td>$(Get-HtmlText $_.Object)</td><td>$(Get-HtmlText $_.Detail)</td></tr>" }) -join ''
            $itemTable = "<table class='items'><thead><tr><th>Object</th><th>Details</th></tr></thead><tbody>$itemRows</tbody></table>"
        }

        $search = Get-HtmlText ("$($r.Id) $($r.Setting) $($r.Summary) " + (($r.Items | ForEach-Object { $_.Object }) -join ' ')).ToLower()

@"
<div class='check' data-status='$($r.Status)' data-id='$($r.Id)' data-search='$search'>
  <div class='row'>
    <label class='review' title='Mark as reviewed'><input type='checkbox' data-review='$($r.Id)'><span></span></label>
    <div class='id'>$($r.Id)</div>
    <div class='main'>
      <div class='title'>$(Get-HtmlText $r.Setting) $deadline</div>
      <div class='summary'>$(Get-HtmlText $r.Summary)</div>
    </div>
    <div class='meta'>
      <span class='badge prio-$($r.Priority.ToLower())'>$($r.Priority)</span>
      <span class='badge license'>$(Get-HtmlText $r.License)</span>
    </div>
    <div class='status-cell'><span class='pill $($r.Status.ToLower())'>$($r.Status)</span>$count</div>
    <div class='chevron'></div>
  </div>
  <div class='detail'>
    <div class='fix'><strong>Recommended:</strong> $(Get-HtmlText $r.Fix)</div>
    $itemTable
    <a class='howto' href='$articleUrl' target='_blank' rel='noopener'>How to configure $($r.Id) &rarr;</a>
  </div>
</div>
"@
    }

@"
<section class='area'>
  <div class='area-head'><h2>$(Get-HtmlText $areas[$area])</h2><span class='area-score'>$areaPass of $areaChecked automated checks passed</span></div>
  $($rows -join "`n")
</section>
"@
}

$secureScoreCard = if ($script:secureScore) {
    "<div class='card'><div class='card-label'>Microsoft Secure Score</div><div class='card-value'>$($script:secureScore.Percentage)%</div><div class='card-sub'>$($script:secureScore.Current) of $($script:secureScore.Max) points</div></div>"
} else { '' }

$criticalCard = "<div class='card'><div class='card-label'>Critical items failing</div><div class='card-value $(if ($criticalFails.Count) { 'red' } else { 'green' })'>$($criticalFails.Count)</div><div class='card-sub'>Fix these first</div></div>"

$css = @'
:root {
  --brand: #3f8aa6; --brand-dark: #2f6d84; --bg: #f4f6f8; --card: #ffffff; --text: #1f2933; --muted: #6b7785; --line: #e3e8ee;
  --pass: #1e8449; --pass-bg: #e3f4ea; --warn: #b9770e; --warn-bg: #fdf1dc; --fail: #c0392b; --fail-bg: #fbe4e1;
  --error: #8e44ad; --error-bg: #f1e4f6; --info: #2874a6; --info-bg: #e2eef7; --manual: #6b7785; --manual-bg: #eceff2;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 14px/1.45 "Segoe UI", -apple-system, BlinkMacSystemFont, Roboto, Helvetica, Arial, sans-serif; }
header { background: var(--brand); color: #fff; padding: 28px 40px 80px; }
header h1 { margin: 0 0 6px; font-size: 26px; font-weight: 600; }
header .tenant { font-size: 15px; opacity: .95; }
header .generated { font-size: 13px; opacity: .8; margin-top: 4px; }
main { max-width: 1200px; margin: -56px auto 40px; padding: 0 24px; }
.cards { display: grid; grid-template-columns: 2fr 1fr 1fr; gap: 16px; margin-bottom: 20px; }
.card { background: var(--card); border-radius: 10px; padding: 18px 20px; box-shadow: 0 1px 3px rgba(16,24,40,.08); }
.card-label { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: .05em; }
.card-value { font-size: 32px; font-weight: 700; margin-top: 4px; }
.card-value.red { color: var(--fail); } .card-value.green { color: var(--pass); }
.card-sub { color: var(--muted); font-size: 13px; }
.bar { display: flex; height: 10px; border-radius: 5px; overflow: hidden; background: var(--line); margin: 12px 0 10px; }
.bar span { display: block; height: 100%; }
.bar .pass { background: var(--pass); } .bar .warn { background: var(--warn); } .bar .fail { background: var(--fail); } .bar .error { background: var(--error); }
.legend { display: flex; flex-wrap: wrap; gap: 14px; font-size: 13px; color: var(--muted); }
.legend b { color: var(--text); }
.dot { display: inline-block; width: 9px; height: 9px; border-radius: 50%; margin-right: 5px; }
.toolbar { position: sticky; top: 0; z-index: 5; background: var(--bg); padding: 12px 0; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
.filter { border: 1px solid var(--line); background: var(--card); color: var(--text); padding: 6px 12px; border-radius: 16px; cursor: pointer; font: inherit; font-size: 13px; }
.filter.active { background: var(--brand); border-color: var(--brand); color: #fff; }
.filter .n { opacity: .7; margin-left: 4px; }
.toolbar input[type=search] { margin-left: auto; padding: 7px 12px; border: 1px solid var(--line); border-radius: 8px; font: inherit; min-width: 220px; }
.toolbar .opt { font-size: 13px; color: var(--muted); display: flex; align-items: center; gap: 6px; cursor: pointer; }
.btn { border: 1px solid var(--line); background: var(--card); padding: 6px 12px; border-radius: 8px; cursor: pointer; font: inherit; font-size: 13px; }
.area { background: var(--card); border-radius: 10px; box-shadow: 0 1px 3px rgba(16,24,40,.08); margin-bottom: 18px; overflow: hidden; }
.area-head { display: flex; justify-content: space-between; align-items: baseline; padding: 14px 20px; border-bottom: 1px solid var(--line); }
.area-head h2 { margin: 0; font-size: 16px; }
.area-score { color: var(--muted); font-size: 13px; }
.check { border-bottom: 1px solid var(--line); }
.check:last-child { border-bottom: 0; }
.row { display: grid; grid-template-columns: 28px 64px 1fr auto 110px 20px; gap: 12px; align-items: center; padding: 12px 20px; cursor: pointer; }
.row:hover { background: #fafbfc; }
.id { font-weight: 700; white-space: nowrap; color: var(--brand-dark); }
.title { font-weight: 600; }
.summary { color: var(--muted); font-size: 13px; margin-top: 2px; }
.meta { display: flex; gap: 6px; flex-wrap: wrap; justify-content: flex-end; }
.badge { display: inline-block; font-size: 11px; padding: 2px 8px; border-radius: 10px; background: var(--manual-bg); color: var(--muted); white-space: nowrap; font-weight: 600; }
.badge.prio-critical { background: var(--fail-bg); color: var(--fail); }
.badge.prio-recommended { background: var(--info-bg); color: var(--info); }
.badge.deadline { background: var(--warn-bg); color: var(--warn); margin-left: 6px; vertical-align: middle; }
.status-cell { display: flex; align-items: center; gap: 6px; }
.pill { display: inline-block; min-width: 62px; text-align: center; font-size: 12px; font-weight: 700; padding: 3px 10px; border-radius: 12px; }
.pill.pass { background: var(--pass-bg); color: var(--pass); } .pill.warn { background: var(--warn-bg); color: var(--warn); }
.pill.fail { background: var(--fail-bg); color: var(--fail); } .pill.error { background: var(--error-bg); color: var(--error); }
.pill.info { background: var(--info-bg); color: var(--info); } .pill.manual { background: var(--manual-bg); color: var(--manual); }
.count { font-size: 11px; color: var(--muted); background: var(--bg); border-radius: 8px; padding: 1px 6px; }
.chevron::after { content: ''; display: block; width: 7px; height: 7px; border-right: 2px solid var(--muted); border-bottom: 2px solid var(--muted); transform: rotate(45deg); transition: transform .15s; }
.check.open .chevron::after { transform: rotate(-135deg); }
.detail { display: none; padding: 0 20px 16px 124px; }
.check.open .detail { display: block; }
.fix { background: var(--bg); border-left: 3px solid var(--brand); padding: 8px 12px; border-radius: 4px; margin-bottom: 10px; }
table.items { width: 100%; border-collapse: collapse; font-size: 13px; margin-bottom: 10px; }
table.items th { text-align: left; color: var(--muted); font-weight: 600; border-bottom: 1px solid var(--line); padding: 6px 8px; }
table.items td { border-bottom: 1px solid var(--line); padding: 6px 8px; vertical-align: top; }
table.items td:first-child { white-space: nowrap; font-weight: 600; }
.howto { color: var(--brand-dark); font-weight: 600; text-decoration: none; font-size: 13px; }
.howto:hover { text-decoration: underline; }
.review { display: flex; align-items: center; cursor: pointer; }
.review input { display: none; }
.review span { width: 18px; height: 18px; border: 2px solid #c2cad3; border-radius: 4px; display: inline-block; position: relative; }
.review input:checked + span { background: var(--pass); border-color: var(--pass); }
.review input:checked + span::after { content: ''; position: absolute; left: 4px; top: 0; width: 5px; height: 10px; border: solid #fff; border-width: 0 2px 2px 0; transform: rotate(45deg); }
.check.reviewed .title, .check.reviewed .summary { opacity: .55; }
.hidden { display: none !important; }
footer { text-align: center; color: var(--muted); font-size: 12px; padding: 10px 0 30px; }
footer a { color: var(--brand-dark); }
@media (max-width: 860px) {
  header { padding: 22px 20px 70px; }
  .cards { grid-template-columns: 1fr; }
  .row { grid-template-columns: 24px 54px 1fr 90px; }
  .meta, .chevron { display: none; }
  .detail { padding-left: 20px; }
}
@media print {
  body { background: #fff; }
  header { padding: 16px 0 16px; background: none; color: var(--text); }
  main { margin-top: 0; max-width: none; }
  .toolbar, .chevron, .howto { display: none; }
  .detail { display: block !important; padding-left: 104px; }
  .card, .area { box-shadow: none; border: 1px solid var(--line); }
  .check { break-inside: avoid; }
}
'@

$js = @'
(function () {
  var tenant = document.body.getAttribute('data-tenant');
  var checks = Array.prototype.slice.call(document.querySelectorAll('.check'));
  var filters = Array.prototype.slice.call(document.querySelectorAll('.filter'));
  var search = document.getElementById('search');
  var hideReviewed = document.getElementById('hideReviewed');
  var current = 'All';

  function storageKey(id) { return 'm365baseline-' + tenant + '-' + id; }
  function load(id) { try { return localStorage.getItem(storageKey(id)) === '1'; } catch (e) { return false; } }
  function save(id, value) { try { localStorage.setItem(storageKey(id), value ? '1' : '0'); } catch (e) { } }

  function apply() {
    var q = (search.value || '').toLowerCase();
    checks.forEach(function (c) {
      var show = (current === 'All' || c.getAttribute('data-status') === current) &&
                 (!q || c.getAttribute('data-search').indexOf(q) !== -1) &&
                 !(hideReviewed.checked && c.classList.contains('reviewed'));
      c.classList.toggle('hidden', !show);
    });
    document.querySelectorAll('.area').forEach(function (a) {
      a.classList.toggle('hidden', a.querySelectorAll('.check:not(.hidden)').length === 0);
    });
  }

  filters.forEach(function (f) {
    f.addEventListener('click', function () {
      filters.forEach(function (x) { x.classList.remove('active'); });
      f.classList.add('active');
      current = f.getAttribute('data-filter');
      apply();
    });
  });

  checks.forEach(function (c) {
    var box = c.querySelector('input[data-review]');
    var id = box.getAttribute('data-review');
    box.checked = load(id);
    c.classList.toggle('reviewed', box.checked);
    box.addEventListener('change', function () {
      save(id, box.checked);
      c.classList.toggle('reviewed', box.checked);
      apply();
    });
    c.querySelector('.review').addEventListener('click', function (e) { e.stopPropagation(); });
    c.querySelector('.row').addEventListener('click', function () { c.classList.toggle('open'); });
  });

  search.addEventListener('input', apply);
  hideReviewed.addEventListener('change', apply);

  document.getElementById('expandAll').addEventListener('click', function () {
    var open = checks.some(function (c) { return !c.classList.contains('open'); });
    checks.forEach(function (c) { c.classList.toggle('open', open); });
    this.textContent = open ? 'Collapse all' : 'Expand all';
  });
  document.getElementById('print').addEventListener('click', function () { window.print(); });
})();
'@

$filterButtons = foreach ($s in 'All', 'Fail', 'Warn', 'Pass', 'Error', 'Manual', 'Info') {
    $n = if ($s -eq 'All') { $sorted.Count } else { Get-Count $s }
    if ($s -ne 'All' -and $n -eq 0) { continue }
    $active = if ($s -eq 'All') { ' active' } else { '' }
    "<button class='filter$active' data-filter='$s'>$s<span class='n'>$n</span></button>"
}

$generated = Get-Date -Format 'd MMMM yyyy, HH:mm'

@"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>Microsoft 365 Security Baseline - $(Get-HtmlText $tenantName)</title>
<style>$css</style>
</head>
<body data-tenant='$($org.id)'>
<header>
  <h1>Microsoft 365 Security Baseline</h1>
  <div class='tenant'>$(Get-HtmlText $tenantName) &middot; $(Get-HtmlText $tenantDomain)</div>
  <div class='generated'>Generated $generated &middot; Tenant ID $($org.id)</div>
</header>
<main>
  <div class='cards'>
    <div class='card'>
      <div class='card-label'>Automated checks passed</div>
      <div class='card-value'>$pass <span style='font-size:18px;color:var(--muted);font-weight:600'>of $checked</span></div>
      <div class='bar'>
        <span class='pass' style='width:$(Get-BarWidth $pass)%'></span><span class='warn' style='width:$(Get-BarWidth $warn)%'></span><span class='fail' style='width:$(Get-BarWidth $fail)%'></span><span class='error' style='width:$(Get-BarWidth $errors)%'></span>
      </div>
      <div class='legend'>
        <span><i class='dot' style='background:var(--pass)'></i>Pass <b>$pass</b></span>
        <span><i class='dot' style='background:var(--warn)'></i>Warn <b>$warn</b></span>
        <span><i class='dot' style='background:var(--fail)'></i>Fail <b>$fail</b></span>
        <span><i class='dot' style='background:var(--error)'></i>Error <b>$errors</b></span>
        <span><i class='dot' style='background:var(--manual)'></i>Manual <b>$(Get-Count 'Manual')</b></span>
        <span><i class='dot' style='background:var(--info)'></i>Info <b>$(Get-Count 'Info')</b></span>
      </div>
    </div>
    $criticalCard
    $secureScoreCard
  </div>

  <div class='toolbar'>
    $($filterButtons -join "`n    ")
    <label class='opt'><input type='checkbox' id='hideReviewed'> Hide reviewed</label>
    <button class='btn' id='expandAll'>Expand all</button>
    <button class='btn' id='print'>Print</button>
    <input type='search' id='search' placeholder='Search checks or objects...'>
  </div>

  $($sections -join "`n")

  <footer>
    Check the box in front of an item to mark it as reviewed. This is saved in your browser for this tenant.<br>
    Based on the <a href='$articleUrl' target='_blank' rel='noopener'>LazyAdmin Microsoft 365 Security Checklist</a>.
  </footer>
</main>
<script>$js</script>
</body>
</html>
"@ | Out-File -FilePath $html -Encoding UTF8

Write-Host ""
Write-Host "  Reports saved to:" -ForegroundColor Yellow
Write-Host "  $html" -ForegroundColor Yellow
Write-Host "  $csv" -ForegroundColor Yellow
if ($detailRows) { Write-Host "  $csvItem" -ForegroundColor Yellow }
Write-Host ""

#endregion