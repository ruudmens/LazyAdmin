<#
.SYNOPSIS
  Import User into Active Directory
.DESCRIPTION
  This script will create new AD users from the given CSV file.
.OUTPUTS
  CSV with Active Direct
.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  19 feb 2024
  Purpose/Change: Init
.EXAMPLE
  Create accounts from CSV file
  .\Import-ADUsers.ps1 -CSVpath c:\temp\users.csv
#>

param(
  [Parameter(
    Mandatory = $false,
    HelpMessage = "Enter the path to the CSV file"
  )]
  [string]$CSVpath
)

# ----
# Default values
# ----

# Default OU for new users
$path = 'OU=Users,OU=Oslo,OU=Sites,DC=lazyadmin,DC=nl'

# Default password for new users
$password = 'welcome@lazyadmin2024'

# Enable new accounts
$enabled = $true

# Email domain (you can also use a column in the CSV file for this)
$domain = '@lazyadmin.nl'

function Get-SamAccountName{
  PARAM(
    [parameter(Mandatory=$true)]
    [string]$givenName,
    [parameter(Mandatory=$true)]
    [string]$surName
  )

  # Create SamAccountName from given- and surname
  return (($givenName.Substring(0,1)) + $surName).Replace('-','').Replace(' ','').Replace("'",'').ToLower()
}

function Get-EmailAddress{
  PARAM(
    [parameter(Mandatory=$true)]
    [string]$givenName,
    [parameter(Mandatory=$true)]
    [string]$surName
  )
  # Format the email address
  $emailAddressFormat = $givenName + "." + $surName

  # Replace hyphens and whitespace, format to lowercase.
  return $emailAddressFormat.Replace('-','').Replace(' ','').Replace("'",'').ToLower() + $domain
}

function Get-Manager{
  PARAM(
    [parameter(Mandatory=$true)]
    [string]$name
  )

  # Get the manager 
  Get-AdUser -Filter {name -like $name} -Properties * | select -ExpandProperty DistinguishedName
}

# Import CSV file and create users
ForEach ($user in (Import-Csv -Path $CSVpath)) {

  # Create the samAccountName and userPrincipalName
  $samAccountName = Get-SamAccountName -givenName $user.givenName -surName $user.surName
  $userPrincipalName = $samAccountName + $domain

  # Set Display Name
  $displayName = $user.givenName.Trim() + " " + $user.surName.Trim()

  # Make sure that user doesn't already exists
  if ((Get-ADUser -Filter {UserPrincipalName -eq $userPrincipalName} -ErrorAction SilentlyContinue)) {
    Write-Host "User $($displayName) already exists" -ForegroundColor Yellow
    continue
  }

  # Get Email address
  $emailAddress = Get-EmailAddress -givenName $user.givenName -surName $user.surName

  # Create all the user properties
  $newUser = @{
    AccountPassWord = (ConvertTo-SecureString -AsPlainText $password -force)
    ChangePasswordAtLogon = $true
    City = $user.city
    Company = $user.company
    Country = $user.country
    Department = $user.department
    Description = $user.description
    DisplayName = $displayName
    EmailAddress = $emailAddress
    Enabled = $enabled
    GivenName = $user.givenName.Trim()
    Manager = if ($user.manager) {Get-Manager -name $user.manager} else {$null}
    Mobile = $user.mobile
    Name = $displayName
    Office = $user.office
    OfficePhone = $user.phone
    Organization = $user.organization
    Path = $path 
    PostalCode = $user.postalcode
    SamAccountName = $samAccountName
    StreetAddress = $user.streetAddress
    Surname = $user.surname.Trim()
    Title = $user.title
    UserPrincipalName = $userPrincipalName
  }

  # Create new user
  try {
    New-ADUser @newUser
    Write-Host "- $displayName account is created" -ForegroundColor Green
  }
  catch {
    Write-Host "Unable to create new account for $displayName" -ForegroundColor red
    Write-Host "Error - $($_.Exception.Message)" -ForegroundColor red
  }
}