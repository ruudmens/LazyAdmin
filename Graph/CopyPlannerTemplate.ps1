#requires -version 4
<#
.SYNOPSIS
  
.DESCRIPTION
  Create a Template Plan with the buckets and defauls tasks
  Grap the planId from the url (last part of the url, after planId=) 
  https://tasks.office.com/contoso.com/nl-NL/Home/Planner/#/plantaskboard?groupId=<GROUP-ID>&planId=AbcDefGhijkLM012

  Do the same for the new plan

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  28 aug 2018
  Purpose/Change: 
  
.EXAMPLE
  Just run the script.

  CopyPlannerTemplate.ps1 -templatePlanId 'AbcDefGhijkLM012' -newPlanId 'AbcDefGhijkLM213'

#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
[CmdletBinding()]
PARAM(
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true)]
	[string]$templatePlanID,

	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true)]
	[string]$newPlanID
)


# Connect to Azure Graph API
connectTo-Graph.ps1

# Store the newly created accessToken
$accessToken = Get-Content $PSScriptRoot"\accessToken.txt"

# Get plan Details
$url = "https://graph.microsoft.com/v1.0/planner/plans/$templatePlanID/details"
$planDetails = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method 'GET' -ContentType 'application/json'

# New plan details for eTag token
$url = "https://graph.microsoft.com/v1.0/planner/plans/$newPlanID/details"
$newPlanDetails = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method 'GET' -ContentType 'application/json'

# Update plan details
$headers = @{
			Authorization = "Bearer $accessToken"
			ContentType = 'application/json'
			'if-match' = $newPlanDetails.'@odata.etag'
		}

$categories = $planDetails.categoryDescriptions | convertTo-Json

$planDetailBody = @"
	{
	  "categoryDescriptions": $($categories)
	}
"@

$url = "https://graph.microsoft.com/v1.0/planner/plans/$newPlanID/details"
Invoke-RestMethod -Headers $headers -Uri $url -Method PATCH -body $planDetailBody -ContentType 'application/json'

# Get all the buckets
$url = "https://graph.microsoft.com/v1.0/planner/plans/$templatePlanID/buckets"
$buckets = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method 'GET' -ContentType 'application/json'

# Get all tasks
$url = "https://graph.microsoft.com/v1.0/planner/plans/$templatePlanID/tasks"
$allTasks = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method 'GET' -ContentType 'application/json'

# Create new buckets in the destination plan
$url = "https://graph.microsoft.com/v1.0/planner/buckets"

$lastBucketOrderHint  = ''

foreach ($bucket in $buckets.value) {	
	$body = @"
	{
	  "name": "$($bucket.name)",
	  "planId": "$newPlanID",
	  "orderHint": "$lastBucketOrderHint !"
	}
"@

	$newBucket = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method 'POST' -body $body -ContentType 'application/json'
	$lastBucketOrderHint = $newBucket.orderHint

	# Get the task for this bucket - Reverse order to get them in right order
	$tasks = $allTasks.value | where bucketId -eq $bucket.id | Sort-Object orderHint -Descending

	$createTaskUrl = "https://graph.microsoft.com/v1.0/planner/tasks"

	foreach ($task in $tasks) {
		# Create the task
		$taskBody = @"
			{
			  "planId": "$newPlanId",
			  "bucketId": "$($newBucket.id)",
			  "title": "$($task.title)"
			}
"@

		$newTask = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $createTaskUrl -Method 'POST' -body $taskBody -ContentType 'application/json'

		# Get the task Description
        $taskDetailsUrl = "https://graph.microsoft.com/v1.0/planner/tasks/$($task.id)/details"
        $taskDetails = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $taskDetailsUrl -Method 'GET' -ContentType 'application/json'

		# Add delay - we need to wait until the task is created
        Start-Sleep -milliseconds 500

        # Get the new task details for the etag
        $newTaskDetailsUrl = "https://graph.microsoft.com/v1.0/planner/tasks/$($newTask.id)/details"
        $newDetails = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $newTaskDetailsUrl -Method 'GET' -ContentType 'application/json'

        # Update task with the details
		$headers = @{
			Authorization = "Bearer $accessToken"
			ContentType = 'application/json'
			'if-match' = $newDetails.'@odata.etag'
		}

		# Add the task description
        if ($task.hasDescription -eq $True) {
           
			$taskUpdateDescription = @"
                {
                    "description": "$($taskDetails.description)",
                    "previewType": "$($taskDetails.previewType)" 
                }
"@
            
            $taskUpdateUrl = "https://graph.microsoft.com/v1.0/planner/tasks/$($newTask.id)/details"

		    Invoke-RestMethod -Headers $headers -Uri $taskUpdateUrl -Method PATCH -body $taskUpdateDescription -ContentType 'application/json'
        }

		# Copy the checklist items
        if (![string]::IsNullOrEmpty($taskDetails.checklist)) {

            $checkListItems = @{}
            foreach ($item in $taskDetails.checklist.psobject.Properties) {
                $guid = [guid]::newGuid().guid

                $checkListItem = @{
                    "@odata.type" = "#microsoft.graph.plannerChecklistItem"
                    "title" = "$($item.value.title)"
                }

                $checkListItems | Add-Member -MemberType NoteProperty -Name $guid -value $checkListItem
            }

            $checkListItemsJson = $checkListItems | ConvertTo-Json

            $taskUpdateChecklist = @"
                {
                    "checklist": $($checkListItemsJson)
                }
"@

            Invoke-RestMethod -Headers $headers -Uri $taskUpdateUrl -Method PATCH -body $taskUpdateChecklist -ContentType 'application/json'
        }
	}
}