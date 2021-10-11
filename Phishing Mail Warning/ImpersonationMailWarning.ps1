<#
.SYNOPSIS
	Impersonation phishing mail warning

.DESCRIPTION
  Add warning to Outlook message when display name matches internal users

.NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  11 oct 2021
  Purpose/Change: Initial script development
  Link:           https://lazyadmin.nl/office-365/warn-users-for-email-impersonation-phishing-mail
#>

# Connect to Exchange Online
Write-Host "Connect to Exchange Online" -ForegroundColor Cyan
Connect-ExchangeOnline

$HTMLDisclaimer = '<table border=0 cellspacing=0 cellpadding=0 align="left" width="100%">
	<tr>
		<td style="background:#ffb900;padding:5pt 2pt 5pt 2pt"></td>
		<td width="100%" cellpadding="7px 6px 7px 15px" style="background:#fff8e5;padding:5pt 4pt 5pt 12pt;word-wrap:break-word">
			<div style="color:#222222;">
				<span style="color:#222; font-weight:bold;">Warning:</span>
				This email was sent from outside the company and it has the same display name as someone inside our organisation. This is probably a phishing mail. Do not click on links or open attachments
				unless you are certain that this email is safe.
			</div>
		</td>
	</tr>
</table>
<br/>'

# Get all existing users
$displayNames = (Get-EXOMailbox -ResultSize unlimited  -RecipientTypeDetails usermailbox).displayname

# Set the transport rule name
$transportRuleName = "Impersonation warning"

# Get existing transport rule
$existingTransportRule =  Get-TransportRule | Where-Object {$_.Name -eq $transportRuleName}

if ($existingTransportRule) 
{
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
else 
{
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

# Close Exchange Online Connection
$close = Read-Host Close Exchange Online connection? [Y] Yes [N] No 

if ($close -match "[yY]") {
  Disconnect-ExchangeOnline -Confirm:$false | Out-Null
}