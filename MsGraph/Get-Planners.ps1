<#
.SYNOPSIS
    This script connects to Microsoft Graph and retrieves Planner plans assigned to Microsoft 365 Groups and/or licensed users.
    It outputs the results to a CSV file or the console, showing details like plan title, creation date, and group/user associations.

.DESCRIPTION
    The script allows querying Planner plans at both the group and user level:
    - When using `-planType groups`, it collects all Microsoft 365 groups with Planner plans.
    - When using `-planType users`, it targets licensed users and retrieves their owned Planner plans.
    - `-planType both` queries both groups and users.

    You can also include groups or users with no plans using the `-listGroupsWithoutPlans` switch.

    Results are exported to a timestamped CSV file by default, unless otherwise specified via `-path`.

    **Important Limitation:**  
    Due to Microsoft Graph permission constraints, the script may fail to retrieve Planner plans for **all users**, 
    especially when the signed-in account lacks access. These failures will appear as error messages or result in incomplete data.

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  May 2025
  Purpose/Change: Initial script development
#>
param(
  [Parameter(
    Mandatory = $false
  )]
  [switch]$listGroupsWithoutPlans = $false,

  [Parameter(
    Mandatory = $false
  )]
  [ValidateSet("groups", "users", "both")]
  [string]$planType = 'both',

  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter path to save the CSV file"
  )]
  [string]$path = ".\ADUsers-$((Get-Date -format "MMM-dd-yyyy").ToString()).csv"
)

function Connect-ToMicrosoftGraph {
    $requiredScopes = @(
        "User.Read.All",
        "Group.Read.All",
        "Tasks.Read"
    )
    
    try {
        # Connect to Microsoft Graph with required scopes
        Connect-MgGraph -Scopes $requiredScopes
        Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to connect to Microsoft Graph: $_"
        exit
    }
}

# Function to get all Microsoft 365 Groups
function Get-AllM365Groups {
    try {
        # Get all Microsoft 365 Groups (filter for groupTypes containing 'Unified')
        $groups = Get-MgGroup -Filter "groupTypes/any(c:c eq 'Unified')" -All
        Write-Host "Retrieved $($groups.Count) Microsoft 365 Groups" -ForegroundColor Green
        return $groups
    }
    catch {
        Write-Error "Failed to retrieve Microsoft 365 Groups: $_"
        return $null
    }
}

function Get-AllM365users {
    try {
        # Get all Microsoft 365 Users that have a license.
        $users = Get-MgUser -Filter 'assignedLicenses/$count ne 0 and UserType eq ''member''' -ConsistencyLevel eventual -CountVariable unlicensedUserCount -All | 
                    Select  'DisplayName','userPrincipalName','id'

        Write-Host "Retrieved $($users.Count) Microsoft 365 Users" -ForegroundColor Green
        return $users
    }
    catch {
        Write-Error "Failed to retrieve Microsoft 365 Users: $_"
        return $null
    }

}

# Function to get all Planner Plans for a specific group
function Get-PlannerPlansForGroup {
    param (
        [Parameter(Mandatory = $true)]
        [string]$groupId,
        [string]$groupDisplayName
    )

    try {
        $plans = Get-MgGroupPlannerPlan -GroupId $groupId

        $owner = $null
        try {
            $owner = (Get-MgGroupOwner -GroupId $groupId | Select-Object -ExpandProperty AdditionalProperties).displayName
        }
        catch {
            Write-Verbose "Failed to get group owner for $groupDisplayName"
        }

        $createObject = {
            param ($plannerId, $plannerTitle, $createdAt)

            [PSCustomObject]@{
                "Group/User Id"   = $groupId
                "Group/User Name" = $groupDisplayName
                "Planner ID"      = $plannerId
                "Planner Title"   = $plannerTitle
                "Group Owner"     = $owner
                "Created at"      = $createdAt
            }
        }

        if (!$plans -or $plans.Count -eq 0) {
            Write-Verbose "No Planner Plans found for group: $groupDisplayName"

            if ($listGroupsWithoutPlans) {
                return &$createObject $null "No Plans" $null
            }
        }

        $planDetails = foreach ($plan in $plans) {
            &$createObject $plan.Id $plan.Title $plan.CreatedDateTime
        }

        return $planDetails
    }
    catch {
        Write-Error "Failed to retrieve Planner Plans for group '$groupDisplayName': $_"

        return [PSCustomObject]@{
            "Group/User Id"   = $groupId
            "Group/User Name" = $groupDisplayName
            "Planner ID"      = $null
            "Planner Title"   = "Error retrieving plans"
            "Group Owner"     = $null
            "Created at"      = $null
        }
    }
}

function Get-PlannerPlansForUser {
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName,
        [string]$userDisplayName,
        [string]$userId
    )

    try {
        write-host "Getting plans for user $userPrincipalName"
        $plans = Get-MgPlannerPlan -filter "owner eq '$UserPrincipalName'"

        $createObject = {
            param ($plannerId, $plannerTitle, $createdAt)

            [PSCustomObject]@{
                "Group/User Id"   = $userId
                "Group/User Name" = $userDisplayName
                "Planner ID"      = $plannerId
                "Planner Title"   = $plannerTitle
                "Group Owner"     = $null
                "Created at"      = $createdAt
            }
        }

        if (!$plans -or $plans.Count -eq 0) {
            Write-Verbose "No Planner Plans found for user: $userDisplayName"

            if ($listGroupsWithoutPlans) {
                return &$createObject $null "No Plans" $null
            }
        }

        $planDetails = foreach ($plan in $plans) {
            &$createObject $plan.Id $plan.Title $plan.CreatedDateTime
        }

        return $planDetails
    }
    catch {
        Write-Error "Failed to retrieve Planner Plans for user '$userDisplayName': $_"

        return [PSCustomObject]@{
            "Group/User Id"   = $userId
            "Group/User Name" = $userDisplayName
            "Planner ID"      = $null
            "Planner Title"   = "Error retrieving plans"
            "Group Owner"     = $null
            "Created at"      = $null
        }
    }
}


# Main script execution
try {
    # Connect to Microsoft Graph
    Connect-ToMicrosoftGraph
    
    if ($planType -eq 'groups' -or $planType -eq 'both') {
        # Get all Microsoft 365 Groups
        $allGroups = Get-AllM365Groups
        
        if ($null -eq $allGroups) {
            Write-Error "No groups were retrieved. Exiting script."
            exit
        }
        
        # Initialize results array
        $results = @()
        
        # Process each group and get its Planner Plans
        $counter = 0
        $totalGroups = $allGroups.Count
        
        foreach ($group in $allGroups) {
            $counter++
            Write-Progress -Activity "Retrieving Planner Plans" -Status "Processing Group $counter of $totalGroups" -PercentComplete (($counter / $totalGroups) * 100)
            
            Write-Verbose "Processing group: $($group.DisplayName)"
            $planDetails = Get-PlannerPlansForGroup -GroupId $group.Id -GroupDisplayName $group.DisplayName
            
            if ($planDetails) {
                $results += $planDetails
            }
        }
    }

    if ($planType -eq 'users' -or $planType -eq 'both') {
        # Get all Microsoft 365 Users
        $allUsers = Get-AllM365users

        if ($null -eq $allUsers) {
            Write-Error "No users were retrieved. Exiting script."
            exit
        }

        # Process each user and get its Planner Plans
        $counter = 0
        $totalUsers = $allUsers.Count

        foreach ($user in $allUsers) {
            $counter++
            Write-Progress -Activity "Retrieving Planner Plans" -Status "Processing User $counter of $totalUsers" -PercentComplete (($counter / $totalUsers) * 100)
            
            Write-Verbose "Processing user: $($user.DisplayName)"
            $planDetails = Get-PlannerPlansForUser -UserId $user.Id -UserDisplayName $user.DisplayName -UserPrincipalName $user.userPrincipalName
            
            if ($planDetails) {
                $results += $planDetails
            }
        }   
    }
    
    # Display results summary
    Write-Host "Results Summary:" -ForegroundColor Cyan
    Write-Host "--------------" -ForegroundColor Cyan

    if ($planType -eq 'groups' -or $planType -eq 'both') {
        Write-Host "Total Microsoft 365 Groups: $totalGroups" -ForegroundColor Cyan
    }
    if ($planType -eq 'users' -or $planType -eq 'both') {
        Write-Host "Total Microsoft 365 Users: $totalUsers" -ForegroundColor Cyan
    }
    Write-Host "Total Planner Plans found: $(($results | Where-Object { $_.PlanId -ne $null }).Count)" -ForegroundColor Cyan

    if ($planType -eq 'groups' -or $planType -eq 'both') {
        Write-Host "Groups without Planner Plans: $(($results | Where-Object { $_.PlanTitle -eq 'No Plans' }).Count)" -ForegroundColor Cyan
    }
    if ($planType -eq 'users' -or $planType -eq 'both') {
        Write-Host "Users without Planner Plans: $(($results | Where-Object { $_.PlanTitle -eq 'No Plans' }).Count)" -ForegroundColor Cyan
    }

    # Export results to CSV
    if ($null -ne $CSVPath) {
        $results | Export-Csv -Path $CSVPath -NoTypeInformation

        if ((Get-Item $CSVPath).Length -gt 0) {
            Write-Host "Report finished and saved in $CSVPath" -ForegroundColor Green

            # Open the CSV file
            Invoke-Item $CSVPath
        }else{
            Write-Host "Failed to create report" -ForegroundColor Red
        }
    }else{
        Write-Host "Groups and their Planner Plans:" -ForegroundColor Yellow
        $results | Format-Table -AutoSize
    }

    
}
catch {
    Write-Error "An error occurred during script execution: $_"
}