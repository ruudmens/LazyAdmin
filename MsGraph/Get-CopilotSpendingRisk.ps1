# Find tenants where a Copilot Business purchase would enable usage-based billing for all users.
# Reads the Copilot licenses and the spending policies per tenant. Read-only, nothing is changed.
#
# Needs: Microsoft.Graph.Authentication module
# Role:  Global Reader, or Global admin / Billing admin / AI admin

# Tenant IDs to check. Leave empty to only check the tenant you sign in to.
$TenantIds = @()

$scopes = @("LicenseAssignment.Read.All", "CopilotCostManagement-Policy.Read.All")
$base   = "https://graph.microsoft.com/beta/copilot/costManagement"

# Service plan that every paid Copilot license includes (Microsoft 365 Copilot in the apps).
# Detecting Copilot by service plan works for the Business bundles as well, whatever their SKU name is.
$copilotPlanId = "a62f8878-de10-42f3-b68f-6149a25ceb97"   # M365_COPILOT_APPS

# Copilot Business SKUs: the standalone add-on and the Business Basic/Standard/Premium bundles.
# Any other SKU with Copilot (Microsoft 365 Copilot, E7, benefit programs) excludes the tenant from the default.
$businessSkuPattern = 'BUSINESS|SPB'

function Get-LimitValue($quantity) {
    if ($quantity.'@odata.type' -like "*unlimited*") { return "Unlimited" }
    return $quantity.value
}

function Get-GraphError($err) {
    if ($err.ErrorDetails.Message) {
        try { return (($err.ErrorDetails.Message | ConvertFrom-Json).error.message) } catch {}
        return $err.ErrorDetails.Message
    }
    return $err.Exception.Message
}

if (-not $TenantIds) { $TenantIds = @($null) }

$tenantReport = @()
$policyReport = @()

foreach ($tenantId in $TenantIds) {

    # Start clean, so a cached token from an earlier session with other scopes isn't reused
    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null

    $connect = @{ Scopes = $scopes; NoWelcome = $true }
    if ($tenantId) { $connect.TenantId = $tenantId }
    Connect-MgGraph @connect

    $tenantName = (Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/organization?`$select=displayName").value[0].displayName

    # Licenses: only SKUs with active units that include Copilot
    $licenseError = $null
    $copilotSkus  = @()
    try {
        $copilotSkus = @((Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/subscribedSkus").value |
            Where-Object { $_.prepaidUnits.enabled -gt 0 -and $_.servicePlans.servicePlanId -contains $copilotPlanId } |
            ForEach-Object { [PSCustomObject]@{ Sku = $_.skuPartNumber; Units = $_.prepaidUnits.enabled } })
    }
    catch { $licenseError = Get-GraphError $_ }

    $copilotBusiness = @($copilotSkus | Where-Object { $_.Sku -match $businessSkuPattern })
    $excluded        = @($copilotSkus | Where-Object { $_.Sku -notmatch $businessSkuPattern })

    # Spending policies
    $policyError = $null
    try { $policies = @((Invoke-MgGraphRequest -Method GET -Uri "$base/spendingPolicies").value | Where-Object { $_ }) }
    catch { $policies = @(); $policyError = Get-GraphError $_ }

    $openPolicy = $false
    foreach ($policy in $policies) {
        $scope = $policy.'@odata.type' -replace '#microsoft.graph.', '' -replace 'SpendingPolicy', ''

        # Is Cowork enabled in this policy?
        $cowork = "Unknown"
        try {
            $services = (Invoke-MgGraphRequest -Method GET -Uri "$base/spendingPolicies/$($policy.id)/serviceSettings").value
            $cowork = ($services | Where-Object serviceId -eq "cowork").state
            if (-not $cowork) { $cowork = "notIncluded" }
        }
        catch {}

        if ($scope -eq "allUsers" -and $policy.status -eq "enabled" -and $cowork -eq "enabled") { $openPolicy = $true }

        $policyReport += [PSCustomObject]@{
            Tenant       = $tenantName
            Policy       = $policy.displayName
            Scope        = $scope
            Status       = $policy.status
            PolicyLimit  = Get-LimitValue $policy.periodLimit
            PerUserLimit = Get-LimitValue $policy.perUserLimit
            Cowork       = $cowork
        }
    }

    $result = if ($licenseError)         { "Unknown: licenses - $licenseError" }
              elseif ($policyError)      { "Unknown: policies - $policyError" }
              elseif ($excluded)         { "Excluded" }
              elseif ($openPolicy)       { "Open" }
              elseif ($policies.Count)   { "Controlled" }
              elseif ($copilotBusiness)  { "At risk" }
              else                       { "Not in scope yet" }

    $tenantReport += [PSCustomObject]@{
        Tenant          = $tenantName
        CopilotBusiness = ($copilotBusiness | ForEach-Object { "$($_.Sku) ($($_.Units))" }) -join ', '
        Excluded        = ($excluded | ForEach-Object { "$($_.Sku) ($($_.Units))" }) -join ', '
        Policies        = $policies.Count
        Result          = $result
    }

    Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
}

$tenantReport | Sort-Object Result | Format-Table -AutoSize -Wrap
$policyReport | Format-Table -AutoSize

$tenantReport | Export-Csv -Path .\Copilot-Spending-Tenants.csv -NoTypeInformation -Encoding UTF8
$policyReport | Export-Csv -Path .\Copilot-Spending-Policies.csv -NoTypeInformation -Encoding UTF8

$atRisk = @($tenantReport | Where-Object { $_.Result -in "At risk", "Open" })
Write-Host "Tenants at risk or open: $($atRisk.Count) of $($tenantReport.Count)" -ForegroundColor Yellow