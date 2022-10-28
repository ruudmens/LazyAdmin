<#
.SYNOPSIS
	Create new Active Directory user
  
.DESCRIPTION
  You don't need to have the Active Directory module installed, it will pull it from the Domain Controller

  The script will request the following details for a new user:
	- Firstname
	- Lastname
	- Phone number
	- Mobile Phone
	- Manager

	It creates the user logonname, we use the fullname for this. If the fullname is already taken (highly unlikely) then the
	alternative firstletter of firstname + lastname will be used.

	Logonname is firstname+lastname@domain.com 

	Company info for emailsignature will be pulled out of the companies.json file. You can at here as many companies / offices 
	as you like. During the account creation you will be asked witch account to use.

	Microsoft 365 licenses are assigned using group based licensing: https://lazyadmin.nl/office-365/office-365-assign-license-to-group/
	Script will check how many licenses are available in your tenant. In the config file you can configure the 
	Microsoft 365 license name (AccountSkuId), check them with Get-MsolAccountSku

	After user is created, it will force the Azure AD sync. Once completed it will force MFA on the user account.

	After account creation additional attributes can be set. 

	When all done, details are emailed the manager of the user. 

	Before you start, check the settings under Declarations to match your environment.

.INPUTS
  companies.json is required in the same folder as this script.
.OUTPUTS
	New Active Directory user
.NOTES
  Version:        1.7
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  26 januari 2017
  Purpose/Change: Script cleanup
  
.EXAMPLE
  Just run the script.
#>

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Set Error Action to Silently Continue
#$ErrorActionPreference = "SilentlyContinue"

# Set script in test mode
$whatIf = $true

# Get the config file
$config = Get-Content $PSScriptRoot"\config.json" -Raw | ConvertFrom-Json

# Get the script location
$rootPath = (Get-Item $PSScriptRoot).FullName

# JSON Data file with company / office details
$companies = $config.Companies
$companyList = $companies.psobject.properties.name

#---------------------------------------------------------[Initialisations]--------------------------------------------------------
Write-Host "                    -------------------------------------------------            " -ForegroundColor Cyan
Write-Host "                    |                                               |						" -ForegroundColor Cyan
Write-Host "                    |               Create new AD User              |						" -ForegroundColor Cyan
Write-Host "                    |                  Version 1.7                  |						" -ForegroundColor Cyan
Write-Host "                    |                                               |						" -ForegroundColor Cyan
Write-Host "                    |          Author R. Mens - LazyAdmin.nl        |						" -ForegroundColor Cyan
Write-Host "                    |                                               |						" -ForegroundColor Cyan
Write-Host "                    -------------------------------------------------            " -ForegroundColor Cyan
Write-Host "`n"

Function Get-MsolConnection {
	Get-MsolDomain -ErrorAction SilentlyContinue | out-null
	$result = $?
	return $result
}

# Connect to Microsoft Online Services
If (-not (Get-MsolConnection)) {
	Write-Host "Connect to Microsoft Online Services..." -ForegroundColor Cyan
  Connect-MsolService
}else{
	Write-Host "Already connected to Microsoft Online Services" -ForegroundColor Green
}

#-----------------------------------------------------------[Functions]------------------------------------------------------------
Function New-DomainUserAccount
{
	Param (
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$false)]
		$manager,
		[parameter(Mandatory=$true)]
		$company,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
    PROCESS{
      Try	{
				Return New-ADUser -SamAccountName $user.samAccountName -name $user.fullName `
							-DisplayName $user.fullName -GivenName $user.givenName -Surname $user.surName `
							-EmailAddress $user.userPrincipalName -UserPrincipalName $user.userPrincipalName `
							-manager $manager.SamAccountName -StreetAddress $company.StreetAddress -PostalCode $company.PostalCode -City $company.city`
							-Office $company.Name -OfficePhone $user.telephoneNumber -MobilePhone $user.mobilePhone -title $user.title `
							-HomePage $company.WebSite  `
							-Enabled $true -ChangePasswordAtLogon $true -PasswordNeverExpires $false -PassThru `
							-AccountPassword (ConvertTo-SecureString -AsPlainText $config.Settings.password -force) -Path $company.OU -WhatIf:$whatif
			} Catch {
				Write-Error "Could not create user $($user.samAccountName), $_"
				Return $false
			}
    }
}

<#
	Set ExtensionAttributes after the user is created.
#>
Function Set-ExtensionAttributes
{
	PARAM(
		[parameter(Mandatory=$true)]
		[string]$samAccountName,
		[parameter(Mandatory=$true)]
		[string]$companyPhone,
		[parameter(Mandatory=$true)]
		[string]$companyWebsite,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
  PROCESS {
		Try {
			Set-ADUser $samAccountName -Add @{extensionAttribute1=$companyPhone} -WhatIf:$whatIf
			Set-ADUser $samAccountName -Add @{extensionAttribute2=$companyWebsite} -WhatIf:$whatIf
		}	Catch	{
			Write-Error "There was a problem adding the extensionAttributes, $_"
			Return $false
		}
	}
}

<#
	Create SamAccountName.
	Check if username exists, in case it exists, return alternative username.
	I prefer to keep the logonnames (SamAccountName) the same format as the emailaddresses

	Logonname principal is firstname + lastname. Example:
	John Doe  > johndoe@company.com
	Klaas de Vries > klaasdevries@company.com

	If it exists the alternative will be:
	John Doe > jdoe@company.com
	Klaas de Vries > kdevries@company.com

	SamAccountNames are limited to 20 characters.
#>
Function Get-SamAccountName
{
	PARAM(
		[parameter(Mandatory=$true)]
		[string]$givenName,
		[parameter(Mandatory=$true)]
		[string]$surName
	)
  PROCESS	{
		#Remove spaces from lastName
		$surName = $surName -replace '\s',''

		#Create username
		$samAccountName = ($givenName + $surName).ToLower()

		#Check lenght
		if ($samAccountName.Length -gt 20) {
			$samAccountName = (($givenName.Substring(0,1)) + $surName).ToLower()
		}

		#Check if username already exists
		$usr = dsquery user -samid $samAccountName
		
		If ($Null -eq $usr) {
			return $samAccountName
		} Else {
			$samAccountName = (($givenName.Substring(0,1)) + $surName).ToLower()
			$usr = dsquery user -samid $samAccountName

			If ($Null -eq $usr) {
				return $samAccountName
			} Else {
				Write-Error "The samAccountName already exists, $_"
				return $false
			}
		}	
	}
}

<#
	Create the userprincipalname
#>
Function Get-UserPrincipalName
{
	PARAM(
		[parameter(Mandatory=$true)]
		[string]$samAccountName,
		[parameter(Mandatory=$true)]
		$company
	)
  PROCESS	{
		$emailDomain = '@' + $company.website
		return $samAccountName + $emailDomain
	}
}

<#
	Create email body for the mail to the manager
#>
Function Get-EmailTemplate
{
	PARAM(
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$manager
	)

	PROCESS
	{
		#Get the mailtemplate
		$mailTemplate = (Get-Content ($rootPath + '\' + $config.Settings.mailTemplateManager)) | ForEach-Object {
			$_ 	-replace '{{manager.firstname}}', $manager.GivenName `
			-replace '{{user.UserPrincipalName}}', $user.UserPrincipalname `
			-replace '{{user.Password}}', $config.Settings.password `
			-replace '{{user.fullname}}', $user.fullName `
			-replace '{{user.firstname}}', $user.givenName
		} | Out-String	
		
		return $mailTemplate
	}
}

<#
	Create email body for the email to the servicedesk
#>
Function Get-ServiceDeskEmailTemplate
{
	PARAM(
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$true)]
		$availableLicenses
	)

	PROCESS
	{
		#Get the mailtemplate
		$mailTemplate = (Get-Content ($rootPath + '\' + $config.Settings.mailTemplateServiceDesk)) | ForEach-Object {
			$_ 	-replace '{{manager.Name}}', $manager.Name `
			-replace '{{user.UserPrincipalName}}', $user.UserPrincipalname `
			-replace '{{user.Password}}', $config.Settings.password `
			-replace '{{user.fullname}}', $user.fullName `
			-replace '{{user.firstname}}', $user.givenName `
			-replace '{{availableLicenses}}', $availableLicenses `
		} | Out-String	
		
		return $mailTemplate
	}
}

<#
	Send mail to manager with the new account details
#>
Function Send-MailtoManager
{
	PARAM(
		[parameter(Mandatory=$true)]
		$emailBody,
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
	
  PROCESS	{
		#Create subject of the email
		$subject = $config.SMTP.subject -replace '{{user.fullname}}', $user.fullName
		
		#Set encoding
		$encoding = [System.Text.Encoding]::UTF8

		Try {
			if ($whatIf -ne $true) {
				Send-MailMessage -SmtpServer $config.SMTP.address -To $manager.mail -From $config.SMTP.from -Subject $subject -Encoding $encoding -Attachment $config.SMTP.attachment -Body $emailBody -BodyAsHtml
				Write-Host "Mail send" -ForegroundColor Green
			} else {
				Write-host ("Send mail to -SmtpServer " + $config.SMTP.address + " -To " + $manager.mail + " -From " + $config.SMTP.from + " -Subject $subject")
			}
		} Catch	{
			Write-Error "Failed to send email to manager, $_"
		}
	}
}

<#
	Send mail to manager with the new account details
#>
Function Send-MailtoServiceDesk
{
	PARAM(
		[parameter(Mandatory=$true)]
		$emailBody,
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$manager,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
	PROCESS	{
		#Create subject of the email
		$subject = $config.SMTP.subject -replace '{{user.fullname}}', $user.fullName
		
		#Set encoding
		$encoding        = [System.Text.Encoding]::UTF8

		try {
			if ($whatIf -ne $true) {
				Send-MailMessage -SmtpServer $config.SMTP.address -To $config.SMTP.serviceDesk -From $config.SMTP.from -Encoding $encoding -Subject $subject -Body $emailBody -BodyAsHtml
				Write-Host "Mail send" -ForegroundColor Green
			} else {
				Write-host ("Send mail to -SmtpServer " + $config.SMTP.address + " -To " + $config.SMTP.serviceDesk + " -From " + $config.SMTP.from + " -Subject $subject")
			}
		} Catch {
			Write-Error "Failed to send email to manager, $_"
		}
	}
}

<#
	Check if the given name for the manager exists in AD
	Return false if name is not found
	Return Manager object with email when found
#>
Function Get-Manager
{
	PARAM(
		[parameter(Mandatory=$true)]
		[string]$name
	)
  Process {
		$managerName = "*$name*"
		$manager = Get-AdUser -Filter {name -like $managerName} -Properties *

		If ($Null -eq $manager) {
			Write-Warning "Manager with $name not found `n"
			return $false
		} ElseIf ($manager.count -gt 1) {
			Write-Warning "Multiple users found, select the correct user `n"
			$managers = $manager
			
			$chooseManager = @()
			For ($index = 0; $index -lt $managers.Count; $index++) {
				$chooseManager += New-Object System.Management.Automation.Host.ChoiceDescription ($managers[$index].name), ($managers[$index].name)
			}

			$options = [System.Management.Automation.Host.ChoiceDescription[]]$chooseManager
			$result = $host.ui.PromptForChoice($title, $message, $options, 1)
			return $managers[$result]
		}	Else {
			Write-Host "You selected $($manager.name)...." -ForegroundColor Cyan
			return $manager
		}
	}
}

<#
	Find the available job titles for the user
	It get's only the titles from the users that are in the same OU, based on the company name
#>
Function Get-JobTitle
{
	PARAM(
		[parameter(Mandatory=$true)]
		$title,
		[parameter(Mandatory=$true)]
		$company
	)
  PROCESS	{
		$city = $company.city

		$usr = Get-ADUser -Filter {(title -eq $title) -and (city -eq $city)} | Sort-Object whenChanged | Select-Object -Last 1

		If ($Null -eq $usr) {
			Write-Warning "No user found with same jobTitle : $title `n"
			$allTitles = Get-AllJobTitles($company)

			Do {
        Write-Host "Choose a job title"

        $index = 1
        $allTitles | ForEach-Object {
            $title = $_.title
            Write-Host "[$index] $title"
            $index++
        }
    
        $selection = Read-Host 
			} Until ($allTitles[$selection-1])

			Write-Host "You selected $($allTitles[$selection-1].title)...." -ForegroundColor Cyan

			return $($allTitles[$selection-1].title)
		}else{
			Write-Host "Jobtitle found" -ForegroundColor Green
			return $title
		}
	}
}

<#
	Find user with the same jobtitle in the same OU (based on company name)
#>
Function Get-UserToCopyGroupsFrom
{
	PARAM(
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$company
	)
  PROCESS {
		$usr = Get-ADUser -Filter {(title -eq $user.title) -and (userPrincipalName -ne $user.userPrincipalName)} -SearchBase $company.ou | 
						Sort-Object whenChanged | Select-Object -Last 1

		If ($Null -eq $usr) {
			Write-Warning "No user found with same jobTitle : $user.title `n"
			return $false
		} Else {
			return $usr
		}
	}
}

<#
	Copy group membership to the new user
#>
Function Set-GroupMemberShip
{
	PARAM(
		[parameter(Mandatory=$true)]
		$user,
		[parameter(Mandatory=$true)]
		$copyFrom,
		[parameter(Mandatory=$false)]
		[bool]$whatIf
	)
  PROCESS	{
		Try	{
			Get-ADUser -Identity $copyFrom -Properties memberOf | Select-Object -ExpandProperty memberOf | Add-ADGroupMember -Members $user -WhatIf:$whatIf
			Write-host 'Membership copied' -ForegroundColor Green
		}	Catch	{
			Write-Error "Failed to add groups, $_"
		}
	}
}

<#
	Get available Microsoft 365 licenses
#>
Function Get-AvailableLicenses
{
	PROCESS {
		$licenseDetails = Get-MsolAccountSku | Where-Object {$_.AccountSkuId -eq $config.Settings.AccountSkuId}
		return $licenseDetails.ActiveUnits - $licenseDetails.ConsumedUnits
	}
}

<#
	Get all job titles
#> 
Function Get-AllJobTitles
{
	PARAM(
		[parameter(Mandatory=$true)]
		$company
	)

	PROCESS	{
		return Get-Aduser -Filter * -SearchBase $company.OU -Properties title | Select-Object title -Unique | Sort-Object -property title
	}
}


#
# ------------------- Start Script ----------------------#
#
if ($whatIf) {
	Write-Host "`n"
	Write-Host "   RUNNING IN TEST MODE   "  -BackgroundColor Yellow -ForegroundColor Black
}

# Creating a new user object
$user = @{}	

# Gathering required details
Write-Host "`n"
Write-Host "Gathering user information...." -ForegroundColor Cyan
Write-Host "Enter the name of the user."

$user.givenName = Read-Host "Firstname"
$user.surName = Read-Host "LastName"

Write-Host "Enter the phonenumber of the user when known"

$user.telephoneNumber = Read-Host "Phone number"
$user.mobilePhone = Read-Host "Mobile phone number"
	    
$user.fullName = ($user.givenName + ' ' + $user.surName)

$usersName = $user.givenName

# Get the company details	
If ($companyList.Count -gt 1) {
	$title = "Select the company"
	$message = "Which company does $usersName work for?"

	# Build the choices menu
	$choices = @()
	For ($index = 0; $index -lt $companyList.Count; $index++) {
		$choices += New-Object System.Management.Automation.Host.ChoiceDescription ($companyList[$index]), ($companyList[$index])
	}

	$options = [System.Management.Automation.Host.ChoiceDescription[]]$choices
	$result = $host.ui.PromptForChoice($title, $message, $options, 1) 
	$company = $companies.($companyList[$result])
}

# Set the manager of the user
$managerName = Read-Host "Who is the manager of the user. Search on first, last or fullname"
$manager = Get-Manager -name $managerName

# Create samAccountname and userPrincipalName
$user.samAccountName = Get-SamAccountName -givenName $user.givenName -surname $user.surName
$user.userPrincipalName = Get-UserPrincipalName -samAccountName $user.samAccountName -company $company

# Job Title
write-host "`n"
write-host "What is the job title of the new user."

$title = Read-Host "Title"

write-host "`n"
write-host "Checking if job title exists...." -ForegroundColor Cyan

$user.title = Get-JobTitle -title $title -company $company
	
# Create the account
write-host "`n"
Write-Host 'Creating User account in AD....' -ForegroundColor Cyan
if ($whatIf) {
	Write-Host "Running in test mode, user won't be created" -ForegroundColor Yellow
}

$userCreated = New-DomainUserAccount -user $user -manager $manager -company $company -whatIf:$whatIf

# Only continue when account is created or when running in whatif (test) mode
If ($userCreated -or $whatIf -eq $true) {
	Write-Host 'User succesfully created' -ForegroundColor Green
	write-Host "`n"
	Write-Host 'Setting additional user settings....' -ForegroundColor Cyan

	# [OPTIONAL] Set additional attributes
	# Set-ExtensionAttributes -samAccountName $user.samAccountName -companyPhone $company.phone -companyWebsite $company.WebSite -whatIf:$whatIf
		
	# Copy Group Membership
	$createdUser = Get-AdUser -Identity $user.SamAccountName -Properties *

	# Find user to copy group membership from
	$userToCopyFrom = Get-UserToCopyGroupsFrom -user $createdUser -company $company

	If ($userToCopyFrom) {
		# Copy group membership from user?

		$title = "Copy group membership?"
		$message = "Do you want to copy the group membership from " + $userToCopyFrom.name + " ?"

		$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
			"Yes"

		$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
			"No"

		$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
		$copyMembership = $host.ui.PromptForChoice($title, $message, $options, 0) 

		if ($copyMembership -eq 0 -and $whatIf -eq $false) {
			Set-GroupMemberShip -user $user.SamAccountName -copyFrom $userToCopyFrom.SamAccountName -whatIf $whatIf
		}
		if ($whatIf) {
			Write-Host "Copy group memberships from $userToCopyFrom.SamAccountName"
		}
	}
	
	# Send email to manager
	write-host "`n"
	Write-Host 'Notifying manager....' -ForegroundColor Cyan

	$emailBody = Get-EmailTemplate -user $user -Manager $manager
	Send-MailtoManager -user $user -manager $manager -EmailBody $emailBody -whatIf $whatIf

	# Send mail to servicedesk
	write-host "`n"
	Write-Host 'Notifying servicedesk....' -ForegroundColor Cyan

	$availableLicenses = Get-AvailableLicenses
	$sdEmailBody = Get-ServiceDeskEmailTemplate -user $user -manager $manager -availableLicenses $availableLicenses
	Send-MailtoServiceDesk -user $user -manager $manager -EmailBody $sdEmailBody -whatIf $whatIf

	# [OPTIONAL] Sync AD's
	# Write-Host "Syncing Active Directory servers...." -ForegroundColor Cyan
	# Repadmin /syncall /AdeP

	# Force Sync of user to Office 365
	write-host "`n"
	Write-Host "Syncing Azure AD Connect...." -ForegroundColor Cyan
	
	# Run command on local domain controller
	Start-ADSyncSyncCycle -PolicyType Delta

	# Run sync command on remote domain controller
	# Invoke-Command -ComputerName lazy-srv-dc02 -ScriptBlock {Start-ADSyncSyncCycle -PolicyType Delta}

	$sa = New-Object -TypeName Microsoft.Online.Administration.StrongAuthenticationRequirement
	$sa.RelyingParty = "*"
	$sa.State = "Enabled"
	$sar = @($sa)

	Do {
		Write-Host "...Waiting for AzureAD sync to complete - 15sec" -ForegroundColor Yellow
		Start-Sleep -s 15
		$msolUser = Get-MsolUser -UserPrincipalName $user.userPrincipalName -ErrorAction SilentlyContinue
	}	While ($null -eq $msolUser)

	Write-Host "Sync completed" -ForegroundColor Green

	# Enable MFA for new user
	write-host "`n"
	Write-Host "Forcing MFA for new user...." -ForegroundColor Cyan
	Set-MsolUser -UserPrincipalName $user.userPrincipalName -StrongAuthenticationRequirements $sar -ErrorAction Stop

	# User created
	write-host "`n"
	Write-Host "   User succesfully created   " -BackgroundColor Green -ForegroundColor White
}else{
	Write-Host "Unable to create user" -ForegroundColor Red
}