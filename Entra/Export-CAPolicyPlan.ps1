<#
.SYNOPSIS
    Backs up Conditional Access policy plans and writes a readable summary.

.DESCRIPTION
    Policy plans (preview) live at their own Graph endpoint, /beta/identity/conditionalAccess/plans.
    Their rules don't show up in Get-MgIdentityConditionalAccessPolicy, so existing CA backup
    scripts and tools miss them.

    This script saves every plan (including its rules) as a JSON file, and writes a Markdown
    summary with the shared conditions and each rule's state, targeting and grant controls.

    Requires: Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups,
              Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Applications,
              Microsoft.Graph.Identity.SignIns
#>
param(
    [string]$ExportFolder = '.\CA-PolicyPlans'
)

Connect-MgGraph -Scopes 'Policy.Read.All', 'Directory.Read.All' -NoWelcome

$guid = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
$nameCache = @{}

# Named locations are resolved once up front
$locationNames = @{}
Get-MgIdentityConditionalAccessNamedLocation -All | ForEach-Object { $locationNames[$_.Id] = $_.DisplayName }

function Resolve-CAObject {
    param([string]$Id, [string]$Type)

    # Keywords like All, None, Office365, AllTrusted are returned as-is
    if ($Id -notmatch $guid) { return $Id }

    $key = "$Type|$Id"
    if ($nameCache.ContainsKey($key)) { return $nameCache[$key] }

    $name = try {
        switch ($Type) {
            'User'     { (Get-MgUser -UserId $Id -Property DisplayName -ErrorAction Stop).DisplayName }
            'Group'    { (Get-MgGroup -GroupId $Id -Property DisplayName -ErrorAction Stop).DisplayName }
            'Role'     { (Get-MgDirectoryRoleTemplate -DirectoryRoleTemplateId $Id -ErrorAction Stop).DisplayName }
            'App'      { (Get-MgServicePrincipal -Filter "appId eq '$Id'" -Property DisplayName -ErrorAction Stop | Select-Object -First 1).DisplayName }
            'Location' { $locationNames[$Id] }
        }
    } catch { $null }

    # Deleted objects stay in the plan as a GUID
    if (-not $name) { $name = "$Id (not found)" }
    $nameCache[$key] = $name
    return $name
}

# Owners can be users or groups
function Resolve-Owner {
    param([string]$Id)
    $name = Resolve-CAObject $Id 'User'
    if ($name -like '*(not found)') { $name = Resolve-CAObject $Id 'Group' }
    $name
}

function Format-List {
    param($Ids, $Type)
    ($Ids | Where-Object { $_ } | ForEach-Object { Resolve-CAObject $_ $Type } | Sort-Object) -join '; '
}

function Format-Targets {
    param($Users, $Groups, $Roles, $Guests)
    $out = @()
    foreach ($id in $Users)  { $out += if ($id -match $guid) { "User: $(Resolve-CAObject $id 'User')" } else { $id } }
    foreach ($id in $Groups) { $out += "Group: $(Resolve-CAObject $id 'Group')" }
    foreach ($id in $Roles)  { $out += "Role: $(Resolve-CAObject $id 'Role')" }
    if ($Guests.guestOrExternalUserTypes) { $out += "Guests: $($Guests.guestOrExternalUserTypes)" }
    ($out | Sort-Object) -join '; '
}

# Markdown table cells can't contain pipes or line breaks
function Format-Cell {
    param([string]$Value)
    if (-not $Value) { return '-' }
    $Value -replace '\|', '/' -replace '\r?\n', ' '
}

function Format-State {
    param([string]$State)
    switch ($State) {
        'enabled'                          { 'On' }
        'disabled'                         { 'Off' }
        'enabledForReportingButNotEnforced' { 'Report-only' }
        default                            { $State }
    }
}

# Turns a condition set (shared conditions or rule conditions) into readable strings
function Get-ConditionSummary {
    param($c)

    if (-not $c) { return [PSCustomObject]@{ UsersInclude = ''; UsersExclude = ''; Resources = ''; Conditions = '' } }

    $u = $c.users
    $a = $c.applications

    $resources = @(
        if ($a.includeApplications) { Format-List $a.includeApplications 'App' }
        if ($a.includeUserActions)  { "Actions: $($a.includeUserActions -join ', ')" }
        if ($a.includeAuthenticationContextClassReferences) { "Auth context: $($a.includeAuthenticationContextClassReferences -join ', ')" }
        if ($a.applicationFilter.rule) { "Filter: $($a.applicationFilter.rule)" }
        if ($a.excludeApplications) { "Exclude: $(Format-List $a.excludeApplications 'App')" }
    ) -join ' / '

    $conditions = @(
        if ($c.clientAppTypes -and $c.clientAppTypes -ne 'all') { "ClientApps: $($c.clientAppTypes -join ',')" }
        if ($c.platforms.includePlatforms)  { "Platforms: $($c.platforms.includePlatforms -join ',')" }
        if ($c.platforms.excludePlatforms)  { "ExcludePlatforms: $($c.platforms.excludePlatforms -join ',')" }
        if ($c.locations.includeLocations)  { "Locations: $(Format-List $c.locations.includeLocations 'Location')" }
        if ($c.locations.excludeLocations)  { "ExcludeLocations: $(Format-List $c.locations.excludeLocations 'Location')" }
        if ($c.signInRiskLevels)            { "SignInRisk: $($c.signInRiskLevels -join ',')" }
        if ($c.userRiskLevels)              { "UserRisk: $($c.userRiskLevels -join ',')" }
        if ($c.devices.deviceFilter.rule)   { "DeviceFilter: $($c.devices.deviceFilter.mode) $($c.devices.deviceFilter.rule)" }
    ) -join ' / '

    [PSCustomObject]@{
        UsersInclude = Format-Targets $u.includeUsers $u.includeGroups $u.includeRoles $u.includeGuestsOrExternalUsers
        UsersExclude = Format-Targets $u.excludeUsers $u.excludeGroups $u.excludeRoles $u.excludeGuestsOrExternalUsers
        Resources    = $resources
        Conditions   = $conditions
    }
}

# Rules keep grant and session controls under 'controls', not at the top level like a policy
function Get-GrantSummary {
    param($Controls)
    $g = $Controls.grantControls
    $grant = if ($g) {
        (@($g.builtInControls) + @($g.authenticationStrength.displayName) | Where-Object { $_ }) -join " $($g.operator) "
    }
    if ($Controls.sessionControls) { $grant = (@($grant, 'session controls') | Where-Object { $_ }) -join ' + ' }
    $grant
}

Write-Host "Reading Conditional Access policy plans..." -ForegroundColor Cyan

# Get all plans, following paging just in case
$plans = @()
$uri = 'https://graph.microsoft.com/beta/identity/conditionalAccess/plans'
do {
    $response = Invoke-MgGraphRequest -Method GET -Uri $uri
    $plans += $response.value
    $uri = $response.'@odata.nextLink'
} while ($uri)

if (-not $plans) {
    Write-Host "No policy plans found in this tenant." -ForegroundColor Yellow
    return
}

New-Item -Path $ExportFolder -ItemType Directory -Force | Out-Null

$md = [System.Collections.Generic.List[string]]::new()
$md.Add("# Conditional Access policy plans")
$md.Add("")
$md.Add("Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') for $((Get-MgContext).Account), $($plans.Count) plans.")
$md.Add("")

foreach ($plan in $plans) {

    # The list call includes the rules, but fetch them if a plan comes back without
    if ($null -eq $plan.rules) {
        $plan.rules = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/identity/conditionalAccess/plans/$($plan.id)/rules").value
    }

    # JSON backup, one file per plan including its rules
    $fileName = ($plan.displayName -replace '[\\/:*?"<>|]', '_') + '.json'
    $plan | ConvertTo-Json -Depth 20 | Set-Content -Path (Join-Path $ExportFolder $fileName) -Encoding UTF8

    # Summary
    $md.Add("## $($plan.displayName)")
    $md.Add("")
    if ($plan.description) { $md.Add("- Description: $($plan.description)") }
    $md.Add("- Owners: $((($plan.owners | ForEach-Object { Resolve-Owner $_ }) -join ', '))")
    if ($plan.tags) { $md.Add("- Tags: $($plan.tags -join ', ')") }
    $md.Add("- Created: $($plan.createdDateTime), modified: $($plan.modifiedDateTime)")
    $md.Add("- Rules: $(@($plan.rules).Count)")
    $md.Add("")

    $shared = Get-ConditionSummary $plan.sharedConditions
    $md.Add("### Shared conditions")
    $md.Add("")
    $md.Add("| Users include | Users exclude | Resources | Conditions |")
    $md.Add("|---|---|---|---|")
    $md.Add("| $(Format-Cell $shared.UsersInclude) | $(Format-Cell $shared.UsersExclude) | $(Format-Cell $shared.Resources) | $(Format-Cell $shared.Conditions) |")
    $md.Add("")

    $md.Add("### Rules")
    $md.Add("")
    $md.Add("| Rule | State | Users include | Users exclude | Resources | Conditions | Grant |")
    $md.Add("|---|---|---|---|---|---|---|")
    foreach ($rule in $plan.rules) {
        $s = Get-ConditionSummary $rule.conditions
        $cells = $rule.displayName, (Format-State $rule.state), $s.UsersInclude, $s.UsersExclude, $s.Resources, $s.Conditions, (Get-GrantSummary $rule.controls) |
            ForEach-Object { Format-Cell $_ }
        $md.Add("| $($cells -join ' | ') |")
    }
    $md.Add("")
}

$summaryPath = Join-Path $ExportFolder 'CA-PolicyPlans-Summary.md'
$md | Set-Content -Path $summaryPath -Encoding UTF8

Write-Host "Exported $($plans.Count) plans to $ExportFolder" -ForegroundColor Green