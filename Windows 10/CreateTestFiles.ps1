<#
  .SYNOPSIS
  Create test files in given directory

  .DESCRIPTION
  The script generates an x amount (by default 10) of text file based test file in the 
  given folder. The files don't contain any content.

  This script is created as an example on writing your own PowerShell scripts.

  .EXAMPLE
  CreateTestFiles.ps1 -path c:\temp -amount 50

  Create 50 files in c:\temp

  .NOTES
  Version:        1.0
  Author:         R. Mens - LazyAdmin.nl
  Creation Date:  04 oct 2022
  Modified Date:  
  Purpose/Change: Init
  Link:           https://lazyadmin.nl/powershell/powershell-scripting
#>
param(
  [Parameter(
    Mandatory = $true,
    HelpMessage = "Enter path were test files should be created"
  )]
  [string]$path,

  [Parameter(
    HelpMessage = "How many files should be created"
  )]
  [int]$amount = 10
)

Function New-TestFiles{
  <#
    .SYNOPSIS
        Create test files
  #>
  param(
    [Parameter(Mandatory = $true)]
    [string]$path
  )
  1..$amount | ForEach-Object {
    $newFile = "$path\test_file_$_.txt";
    New-Item $newFile
  }
}

# Ask for confirmation
Write-host "Creating $amount test files in $path" -ForegroundColor Cyan
$reply = Read-Host -Prompt "Is this correct? [Y] Yes [N] No "

if ( $reply -match "[yY]" ) { 
    New-TestFiles -path $path
}