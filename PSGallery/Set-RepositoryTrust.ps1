<#
.SYNOPSIS
    Modify the OneGet aka PackageManagement.nupkg Repositories variable.
.DESCRIPTION
    Set-RepositoryTrust allows you to add or remove Repositories to your Nuget PATH variable with logic that prevents duplicates.
.PARAMETER AddRepo
    A path that you wish to add. Can be specified with or without a trailing slash.
.PARAMETER RemoveRepo
    A path that you wish to remove. Can be specified with or without a trailing slash.
.PARAMETER Scope
    The scope of the variable to edit. Either Process, User, or Machine.
    If you specify Machine, you must be running as administrator or using Gsudo.
.EXAMPLE
    Set-RepositoryTrust -AddRepo PSgallery 
    Set-RepositoryTrust -RemoveRepo PSgallery
    Set-RepositoryTrust -AddRepo Chocolatey 
    Set-RepositoryTrust -RemoveRepo Chocolatey
    This will add the PSgallery repository and remove the Chocolatey repository. The Scope will be set to Process, which is the default.
.INPUTS
    0
.OUTPUTS
    0
.NOTES
    Author: PhilipProchazka
    Created for: Storing Rest API links
#>

function Set-RepositoryTrust {
    param (
        [string]$AddRepo,
        [string]$RemoveRepo,
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process'
    )

    # Helper function to ensure proper format of repository path
    function Normalize-RepoPath {
        param (
            [string]$Path
        )
        return [regex]::Escape((Resolve-Path -Path $Path).Path)
    }

    $repositoryPaths = @()

    # Normalize and add repository path if provided
    if ($PSBoundParameters.ContainsKey('AddRepo')) {
        $repositoryPaths += Normalize-RepoPath -Path $AddRepo
    }

    # Normalize and remove repository path if provided
    if ($PSBoundParameters.ContainsKey('RemoveRepo')) {
        $repositoryPaths += Normalize-RepoPath -Path $RemoveRepo
    }

    # Register repositories based on the provided parameter
    if ($AddRepo) {
        switch ($AddRepo.ToLower()) {
            'psgallery' {
                Register-PackageSource -Name "PowershellGet" -Location "https://www.powershellgallery.com/api/v2" -ProviderName "PSGallery" -Trusted -Scope $Scope
            }
            'nuget' {
                Register-PackageSource -Name "Nuget.org" -Location "https://api.nuget.org/v3/index.json" -ProviderName "Nuget" -Trusted -Scope $Scope
            }
            'chocolatey' {
                Register-PackageSource -Name "ChocolateyGet" -Location "https://community.chocolatey.org/api/v2" -ProviderName "PowerShellGet" -Trusted -Scope $Scope
            }
            default {
                Write-Error "Unknown repository: $AddRepo"
            }
        }
    }

    # Unregister repositories based on the provided parameter
    if ($RemoveRepo) {
        switch ($RemoveRepo.ToLower()) {
            'psgallery' {
                Unregister-PackageSource -Name "PowershellGet" -ProviderName "PSGallery" -Scope $Scope
            }
            'nuget' {
                Unregister-PackageSource -Name "Nuget.org" -ProviderName "Nuget" -Scope $Scope
            }
            'chocolatey' {
                Unregister-PackageSource -Name "ChocolateyGet" -ProviderName "PowerShellGet" -Scope $Scope
            }
            default {
                Write-Error "Unknown repository: $RemoveRepo"
            }
        }
    }
}

# Example calls to the function
Set-RepositoryTrust -AddRepo "PSgallery"
Set-RepositoryTrust -RemoveRepo "PSgallery"
Set-RepositoryTrust -AddRepo "Chocolatey"
Set-RepositoryTrust -RemoveRepo "Chocolatey"
Set-RepositoryTrust -AddRepo "Nuget"
Set-RepositoryTrust -RemoveRepo "Nuget"