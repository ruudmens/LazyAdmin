<#
.SYNOPSIS
    Finds Conditional Access policies that are candidates to merge into a policy plan.

.DESCRIPTION
    Groups policies the way Microsoft recommends for policy plans: by persona (same users),
    by protected resource (same apps) and by shared condition. For each candidate it predicts
    what the migration tool will move to the plan's shared conditions, and what you need to
    add yourself after the merge.

    The prediction is based on how the preview migration behaves in testing:
    - A setting is only shared when it's identical in every selected policy.
    - Users are only shared when the full assignment (include and exclude) matches,
      and the include isn't All users. Matching exclusions alone are not moved.
    - All users and All resources can't be set at plan level.

    Requires: Microsoft.Graph.Identity.SignIns, Microsoft.Graph.Users, Microsoft.Graph.Groups,
              Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Applications
#>
param(
    # Only include policies whose name matches this pattern, for example 'CA*'. Default: all policies
    [string]$NamePattern = '*',

    # Policies that are Off are skipped, unless you add this switch
    [switch]$IncludeDisabled,

    [string]$ExportPath = '.\CA-PolicyPlan-Candidates.md'
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

    # Deleted objects stay in the policy as a GUID
    if (-not $name) { $name = "$Id (not found)" }
    $nameCache[$key] = $name
    return $name
}

function Format-Targets {
    param($Users, $Groups, $Roles, $Guests)
    $out = @()
    foreach ($id in $Users)  { $out += if ($id -match $guid) { "User: $(Resolve-CAObject $id 'User')" } else { $id } }
    foreach ($id in $Groups) { $out += "Group: $(Resolve-CAObject $id 'Group')" }
    foreach ($id in $Roles)  { $out += "Role: $(Resolve-CAObject $id 'Role')" }
    if ($Guests.GuestOrExternalUserTypes) { $out += "Guests: $($Guests.GuestOrExternalUserTypes)" }
    ($out | Sort-Object -Unique) -join '; '
}

function Format-List {
    param($Ids, $Type)
    ($Ids | Where-Object { $_ } | ForEach-Object { Resolve-CAObject $_ $Type } | Sort-Object) -join '; '
}

function Format-IncludeExclude {
    param([string]$Include, [string]$Exclude)
    (@(
        if ($Include) { "Include: $Include" }
        if ($Exclude) { "Exclude: $Exclude" }
    )) -join ' / '
}

function Format-State {
    param([string]$State)
    switch ($State) {
        'enabled'                           { 'On' }
        'disabled'                          { 'Off' }
        'enabledForReportingButNotEnforced' { 'Report-only' }
        default                             { $State }
    }
}

# Long lists like 14 admin roles are shortened in headings and console output
function Format-Short {
    param([string]$Value, [int]$Max = 3)
    $items = @($Value -split '; ' | Where-Object { $_ })
    if ($items.Count -le $Max) { return ($items -join ', ') }
    "$(($items | Select-Object -First $Max) -join ', ') +$($items.Count - $Max) more"
}

# Returns the items that appear in every list (used for common exclusions)
function Get-CommonItems {
    param([string[]]$Lists)
    $common = @($Lists[0] -split '; ' | Where-Object { $_ })
    foreach ($list in $Lists | Select-Object -Skip 1) {
        $items = $list -split '; '
        $common = @($common | Where-Object { $_ -in $items })
    }
    ($common | Select-Object -Unique) -join '; '
}

# Markdown table cells can't contain pipes or line breaks
function Format-Cell {
    param([string]$Value)
    if (-not $Value) { return '-' }
    $Value -replace '\|', '/' -replace '\r?\n', ' '
}

# The conditions we compare, with the label the portal uses
$conditionFields = [ordered]@{
    ClientApps   = 'Client apps'
    Platforms    = 'Device platforms'
    Locations    = 'Locations'
    SignInRisk   = 'Sign-in risk'
    UserRisk     = 'User risk'
    DeviceFilter = 'Device filter'
}

Write-Host "Reading Conditional Access policies..." -ForegroundColor Cyan
$policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object {
    $_.DisplayName -like $NamePattern -and ($IncludeDisabled -or $_.State -ne 'disabled')
}

if (-not $policies) {
    Write-Host "No policies found that match '$NamePattern'." -ForegroundColor Yellow
    return
}

$rows = foreach ($p in $policies) {
    $c = $p.Conditions

    $usersInclude = Format-Targets $c.Users.IncludeUsers $c.Users.IncludeGroups $c.Users.IncludeRoles $c.Users.IncludeGuestsOrExternalUsers
    $appsInclude  = (@(
                        Format-List $c.Applications.IncludeApplications 'App'
                        if ($c.Applications.IncludeUserActions) { "Actions: $($c.Applications.IncludeUserActions -join ', ')" }
                        if ($c.Applications.IncludeAuthenticationContextClassReferences) { "Auth context: $($c.Applications.IncludeAuthenticationContextClassReferences -join ', ')" }
                    ) | Where-Object { $_ }) -join '; '

    $notes = @(
        if ($usersInclude -eq 'None') { 'Targets no users' }
        if ($c.Applications.IncludeApplications -contains 'None') { 'Targets no resources' }
        if ($c.Locations.IncludeLocations -or $c.Locations.ExcludeLocations) { 'Location: no instant CAE IP enforcement in plans (preview)' }
    ) -join '; '

    [PSCustomObject]@{
        Policy       = $p.DisplayName
        State        = Format-State $p.State
        UsersInclude = $usersInclude
        UsersExclude = Format-Targets $c.Users.ExcludeUsers $c.Users.ExcludeGroups $c.Users.ExcludeRoles $c.Users.ExcludeGuestsOrExternalUsers
        AppsInclude  = $appsInclude
        AppsExclude  = Format-List $c.Applications.ExcludeApplications 'App'
        ClientApps   = ($c.ClientAppTypes -join ',')
        Platforms    = Format-IncludeExclude ($c.Platforms.IncludePlatforms -join ',') ($c.Platforms.ExcludePlatforms -join ',')
        Locations    = Format-IncludeExclude (Format-List $c.Locations.IncludeLocations 'Location') (Format-List $c.Locations.ExcludeLocations 'Location')
        SignInRisk   = ($c.SignInRiskLevels -join ',')
        UserRisk     = ($c.UserRiskLevels -join ',')
        DeviceFilter = $c.Devices.DeviceFilter.Rule
        Grant        = (@($p.GrantControls.BuiltInControls) + @($p.GrantControls.AuthenticationStrength.DisplayName) | Where-Object { $_ }) -join " $($p.GrantControls.Operator) "
        Notes        = $notes
    }
}

# Collect candidate groups. The same set of policies can match on more than one thing,
# so those are merged into one candidate with multiple reasons.
$candidates = [System.Collections.Generic.List[object]]::new()

function Add-Candidate {
    param($Group, [string]$Reason)
    $key = ($Group.Policy | Sort-Object) -join '|'
    $existing = $candidates | Where-Object Key -eq $key
    if ($existing) { $existing.Reasons += $Reason; return }
    $candidates.Add([PSCustomObject]@{ Key = $key; Policies = @($Group); Reasons = @($Reason) })
}

# Persona: same users, include and exclude
$rows | Where-Object { $_.UsersInclude -and $_.UsersInclude -ne 'None' } |
    Group-Object -Property { "$($_.UsersInclude)#$($_.UsersExclude)" } | Where-Object Count -gt 1 |
    ForEach-Object { Add-Candidate $_.Group "Same users: $(Format-Short $_.Group[0].UsersInclude)" }

# Resource: same apps or user actions. All resources is too broad to be a useful group.
$rows | Where-Object { $_.AppsInclude -and $_.AppsInclude -notin 'All', 'None' } |
    Group-Object -Property { "$($_.AppsInclude)#$($_.AppsExclude)" } | Where-Object Count -gt 1 |
    ForEach-Object { Add-Candidate $_.Group "Same resources: $(Format-Short $_.Group[0].AppsInclude)" }

# Condition: same value for one condition. Client apps 'all' is the default, so it's skipped.
foreach ($field in $conditionFields.Keys) {
    $rows | Where-Object { $_.$field -and $_.$field -ne 'all' } |
        Group-Object -Property $field | Where-Object Count -gt 1 |
        ForEach-Object { Add-Candidate $_.Group "Same $($conditionFields[$field].ToLower()): $($_.Name)" }
}

# Predict what the migration moves to the plan, and what you need to add yourself
foreach ($candidate in $candidates) {
    $group = $candidate.Policies
    $shared = @()
    $manual = @()

    $sameUsers = @($group | ForEach-Object { "$($_.UsersInclude)#$($_.UsersExclude)" } | Select-Object -Unique).Count -eq 1
    if ($sameUsers -and $group[0].UsersInclude -ne 'All') {
        $shared += "Users: $(Format-IncludeExclude (Format-Short $group[0].UsersInclude) $group[0].UsersExclude)"
    } else {
        $commonExclusions = Get-CommonItems $group.UsersExclude
        if ($commonExclusions) { $manual += "Add to the plan's excluded users: $commonExclusions" }
        if ($sameUsers) { $manual += "All users can't be set at plan level, so it stays in each rule" }
    }

    $sameApps = @($group | ForEach-Object { "$($_.AppsInclude)#$($_.AppsExclude)" } | Select-Object -Unique).Count -eq 1
    if ($sameApps -and $group[0].AppsInclude -and $group[0].AppsInclude -ne 'All') {
        $shared += "Resources: $(Format-Short $group[0].AppsInclude)"
    }

    foreach ($field in $conditionFields.Keys) {
        $values = @($group | ForEach-Object { $_.$field } | Select-Object -Unique)
        if ($values.Count -eq 1 -and $values[0]) {
            $shared += "$($conditionFields[$field]): $(if ($values[0] -eq 'all') { 'All' } else { $values[0] })"
        }
    }

    $candidate | Add-Member -NotePropertyName Shared -NotePropertyValue $shared
    $candidate | Add-Member -NotePropertyName Manual -NotePropertyValue $manual
}

# How often each exclusion is used. The top one is usually your break-glass account.
$exclusionCounts = $rows | ForEach-Object { $_.UsersExclude -split '; ' | Where-Object { $_ } | Select-Object -Unique } |
    Group-Object | Sort-Object Count -Descending
$topExclusion = if ($exclusionCounts) { $exclusionCounts[0].Name }
$missingTop = if ($topExclusion) { $rows | Where-Object { ($_.UsersExclude -split '; ') -notcontains $topExclusion } }

# ---------- Console output ----------

Write-Host "`nFound $($candidates.Count) merge candidates in $($rows.Count) policies" -ForegroundColor Green

$i = 0
foreach ($candidate in $candidates) {
    $i++
    Write-Host "`nCandidate $i - $($candidate.Reasons -join ' + ')" -ForegroundColor Yellow
    ($candidate.Policies | Select-Object Policy, State, Grant | Format-Table -AutoSize | Out-String).TrimEnd() | Write-Host

    Write-Host "  Shared by the migration: " -NoNewline
    if ($candidate.Shared) { Write-Host ($candidate.Shared -join '; ') -ForegroundColor Green } else { Write-Host 'nothing' -ForegroundColor DarkGray }
    foreach ($m in $candidate.Manual) { Write-Host "  After the merge: $m" -ForegroundColor Cyan }
}

if ($missingTop) {
    Write-Host "`nPolicies without $topExclusion :" -ForegroundColor Red
    $missingTop.Policy | ForEach-Object { Write-Host "  $_" }
}

# ---------- Markdown report ----------

$md = [System.Collections.Generic.List[string]]::new()
$md.Add("# Conditional Access policy plan candidates")
$md.Add("")
$md.Add("Generated $(Get-Date -Format 'yyyy-MM-dd HH:mm') for $((Get-MgContext).Account), $($rows.Count) policies matching ``$NamePattern``$(if (-not $IncludeDisabled) { ' (Off policies skipped)' }).")
$md.Add("")

$md.Add("## Merge candidates")
$md.Add("")
if (-not $candidates) { $md.Add("No policies share users, resources or conditions."); $md.Add("") }

$i = 0
foreach ($candidate in $candidates) {
    $i++
    $md.Add("### Candidate $i")
    $md.Add("")
    $md.Add("Matched on: $($candidate.Reasons -join ', ')")
    $md.Add("")
    $md.Add("| Policy | State | Grant |")
    $md.Add("|---|---|---|")
    foreach ($r in $candidate.Policies) { $md.Add("| $(Format-Cell $r.Policy) | $($r.State) | $(Format-Cell $r.Grant) |") }
    $md.Add("")
    $md.Add("- Shared by the migration: $(if ($candidate.Shared) { Format-Cell ($candidate.Shared -join '; ') } else { 'nothing' })")
    foreach ($m in $candidate.Manual) { $md.Add("- After the merge: $m") }
    $md.Add("")
}

$md.Add("## Exclusions")
$md.Add("")
if ($exclusionCounts) {
    $md.Add("| Exclusion | Used in |")
    $md.Add("|---|---|")
    foreach ($e in $exclusionCounts) { $md.Add("| $(Format-Cell $e.Name) | $($e.Count) of $($rows.Count) policies |") }
    if ($missingTop) {
        $md.Add("")
        $md.Add("Policies without **$topExclusion**: $($missingTop.Policy -join ', ')")
    }
} else {
    $md.Add("**No exclusions found.** Check if your policies exclude your emergency access accounts.")
}
$md.Add("")

# One small vertical table per policy instead of one very wide table
$md.Add("## Policy details")
$md.Add("")
foreach ($r in $rows | Sort-Object Policy) {
    $md.Add("### $(Format-Cell $r.Policy)")
    $md.Add("")
    $md.Add("| Setting | Value |")
    $md.Add("|---|---|")
    $details = [ordered]@{
        'State'          = $r.State
        'Users include'  = $r.UsersInclude
        'Users exclude'  = $r.UsersExclude
        'Resources'      = $r.AppsInclude
        'Exclude resources' = $r.AppsExclude
    }
    foreach ($field in $conditionFields.Keys) {
        if ($field -eq 'ClientApps' -and $r.ClientApps -eq 'all') { continue }
        $details[$conditionFields[$field]] = $r.$field
    }
    $details['Grant'] = $r.Grant
    $details['Notes'] = $r.Notes

    foreach ($key in $details.Keys) {
        if ($details[$key] -or $key -in 'State', 'Users include', 'Grant') { $md.Add("| $key | $(Format-Cell $details[$key]) |") }
    }
    $md.Add("")
}

$md | Set-Content -Path $ExportPath -Encoding UTF8
Write-Host "`nReport saved to $ExportPath" -ForegroundColor Green