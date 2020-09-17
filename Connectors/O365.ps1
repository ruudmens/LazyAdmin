#Set remoteSigned to run scripts for O365
Set-ExecutionPolicy RemoteSigned

#Get credentials en store them
$credential = Get-Credential

#Connect to office 365
Import-Module MsOnline

$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $credential -Authentication Basic -AllowRedirection
Import-PSSession $Session

Connect-MsolService -Credential $credential
Get-MsolUser | Where-Object { $_.isLicensed -eq "TRUE" } | Export-Csv c:\users\rmens\desktop\LicensedUsers.csv