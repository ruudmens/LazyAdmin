<#
.SYNOPSIS
	Impersonation phishing mail warning

.DESCRIPTION
  Add warning to Outlook message when display name matches internal users

.NOTES
  Version:        1.1
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  11 oct 2021
  Purpose/Change: Fix chunk loop and updating part
  Link:           https://lazyadmin.nl/office-365/warn-users-for-email-impersonation-phishing-mail
#>

# Connect to Exchange Online
Write-Host "Connect to Exchange Online" -ForegroundColor Cyan
Connect-ExchangeOnline -ShowBanner:$false

$HTMLDisclaimer = '<table border=0 cellspacing=0 cellpadding=0 align="left" width="100%">
	<tr>
		<td style="background:#ffb900;padding:5pt 2pt 5pt 2pt"></td>
		<td width="100%" cellpadding="7px 6px 7px 15px" style="background:#fff8e5;padding:5pt 4pt 5pt 12pt;word-wrap:break-word">
			<div style="color:#222222;">
				<span style="color:#222; font-weight:bold;">Warning:</span>
				This email was sent from outside the company, and it has the same display name as someone inside our organization. This is probably a phishing mail. Do not click on links or open attachments
				unless you are certain that this email is safe.
			</div>
		</td>
	</tr>
</table>
<br/>'

# Set the size of the chunk, recommend 100
$chunkSize = 100

Function Remove-ExistingRules {
	param(
    [Parameter(Mandatory = $true)]
    [array]$rules
  )
  Foreach ($rule in $rules) {
    Start-Sleep -s 2
    Remove-TransportRule -identity $rule -Confirm:$true
    Write-host "$($rule) deleted" -ForegroundColor Cyan

  }
}

# Get all existing users
$displayNames = (Get-EXOMailbox -ResultSize unlimited  -RecipientTypeDetails usermailbox).displayname

#sort the display names
$displaynames = $displayNames | Sort-Object

# Set the transport rule name
$transportRuleName = "Impersonation warning"

# Get existing transport rule
$existingTransportRule =  Get-TransportRule | Where-Object {$_.Name -like $transportRuleName+"*"}


If ($null -ne ($existingTransportRule)){
	Write-host "Existing impersonation rule(s) found" -ForegroundColor Cyan

	if ($displayNames.Count -gt $chunkSize) {
		# Updating chunks isn't possible, deleting existing rules
		Write-host "Need to use multiple rules, deleting existing impersonation rules" -ForegroundColor Yellow
		
		Remove-ExistingRules -rules $existingTransportRule
	}
}

# Creating multiple rules when we have more then 100 users
if ($displayNames.Count -gt $chunkSize) {

	$chunks = [System.Collections.ArrayList]::new()
	for ($i = 0; $i -lt $displayNames.Count; $i += $chunkSize) {
		if (($displayNames.Count - $i) -gt ($chunkSize -1)  ) {
			$chunks.add($displayNames[$i..($i + ($chunkSize -1))])
		}
		else {
			$chunks.add($displayNames[$i..($displayNames.Count - 1)])
		}
	}

  # Creating new transport rules using chunks
  $c = 0;
  foreach ($chunk in $chunks) {
    Write-Host "Creating Transport Rule" -ForegroundColor Cyan

    # Create new Transport Rule
    New-TransportRule -Name "$transportRuleName-$C" `
                      -FromScope NotInOrganization `
                      -SentToScope InOrganization `
                      -HeaderMatchesMessageHeader From `
                      -HeaderMatchesPatterns $chunk `
                      -ApplyHtmlDisclaimerLocation Prepend `
                      -ApplyHtmlDisclaimerText $HTMLDisclaimer `
                      -ApplyHtmlDisclaimerFallbackAction Wrap

    Write-Host "Transport rule $c created" -ForegroundColor Green
    $c++;
  }
}elseif($existingTransportRule) {
  Write-Host "Update Transport Rule" -ForegroundColor Cyan

  # Update existing Transport Rule
  Set-TransportRule -Identity $transportRuleName `
                    -FromScope NotInOrganization `
                    -SentToScope InOrganization `
                    -HeaderMatchesMessageHeader From `
                    -HeaderMatchesPatterns $displayNames `
                    -ApplyHtmlDisclaimerLocation Prepend `
                    -ApplyHtmlDisclaimerText $HTMLDisclaimer `
                    -ApplyHtmlDisclaimerFallbackAction Wrap

  Write-Host "Transport rule updated" -ForegroundColor Green
}
else {
  Write-Host "Creating Transport Rule" -ForegroundColor Cyan

  # Create new Transport Rule
  New-TransportRule -Name $transportRuleName `
                    -FromScope NotInOrganization `
                    -SentToScope InOrganization `
                    -HeaderMatchesMessageHeader From `
                    -HeaderMatchesPatterns $displayNames `
                    -ApplyHtmlDisclaimerLocation Prepend `
                    -ApplyHtmlDisclaimerText $HTMLDisclaimer `
                    -ApplyHtmlDisclaimerFallbackAction Wrap

  Write-Host "Transport rule created" -ForegroundColor Green
}

# Get the transport rules again so we can open a browser directly to it (only link to the first rule found)
$existingTransportRule = Get-TransportRule | Where-Object {$_.Name -like $transportRuleName+"*"} | Select-Object -First 1

#build the URL
$urlPrefix = "https://admin.exchange.microsoft.com/#/transportrules/:/ruleDetails/"
$ruleURL = $urlPrefix + $existingtransportrule.Guid + "/viewinflyoutpanel"

# Open a browser to the Transport Rule
write-host "Rule URL: " -NoNewline
write-host $ruleURL -ForegroundColor Cyan
$OpenInProwser = Read-Host Open browser to URL? [Y] Yes [N] No 

if ($OpenInProwser -match "[yY]") {
  Start-Process $ruleURL
}

# Close Exchange Online Connection
$close = Read-Host Close Exchange Online connection? [Y] Yes [N] No 

if ($close -match "[yY]") {
  Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}
