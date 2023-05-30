
# Optional Import-Module Microsoft.Graph.Sites
Connect-MgGraph -Scopes "Sites.Read.All, Sites.ReadWrite.All, TermStore.ReadWrite.All"

$siteId = "thunnissenonline.sharepoint.com"

# Get root term store
Get-MgSiteTermStore -siteId "thunnissenonline.sharepoint.com"

# Get term store groups
Get-MgSiteTermStoreGroup -SiteId $siteId

$groupId = 
# Get the term store set
Get-MgSiteTermStoreGroupSet -SiteId $siteId -GroupId $groupId

$params = @{
	Labels = @(
		@{
			LanguageTag = "en-US"
			Name = "Car"
			IsDefault = $true
		}
	)
}

New-MgSiteTermStoreSetChild -SiteId $siteId -SetId $setId -BodyParameter $params