#requires -version 4
<#
.SYNOPSIS
  
.DESCRIPTION
  

.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  28 aug 2018
  Purpose/Change: 
  
.EXAMPLE
  Just run the script.

.TODO
	- Add Default groups
	- Add User to Exchange Online group (maybe seperate script?)
	- Check license availablity (maybe seperate script?)
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------
[CmdletBinding()]
PARAM(
	[parameter(ValueFromPipeline=$true,
				ValueFromPipelineByPropertyName=$true,
				Mandatory=$true)]
	[string]$groupName
)



# Connect to Azure Graph API
connectTo-Graph.ps1

# Store the newly created accessToken
$accessToken = Get-Content $PSScriptRoot"\accessToken.txt"

# Connect to Exchange Online
#connectTo-ExchangeOnline.ps1


# Get Group ID from newly created Office 365 Group
$GroupId = Get-UnifiedGroup -Identity $groupName | select ExternalDirectoryObjectId

# Create payload to get all plans
$task = @"
{
  "name": "Test vanuit Graph",
  "planId": "",
  "orderHint": " !"
}
"@

# Set URL to send request
$url = 'https://graph.microsoft.com/v1.0/planner/buckets'
$method = 'POST'

# GET available plans
$plans = Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method $method -body $task -ContentType 'application/json'
$planId = $plans.planId

# Create plan
$bucket = @"
{
	"name": "backlog",
	"planId": "$planId",
	"orderHint": " !"
}
"@

# Set url and method
$url = 'https://graph.microsoft.com/v1.0/planner/buckets'
$method = 'POST'

# Create Bucket
Invoke-RestMethod -Headers @{Authorization = "Bearer $accessToken"} -Uri $url -Method $method -body $bucket -ContentType 'application/json'