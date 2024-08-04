# I add the switch Trusted because I trust all the modules and scripts from Powershell Gallery
Register-PSRepository -Default -InstallationPolicy Trusted

Register-PSRepository -Name PSGallery -SourceLocation https://www.powershellgallery.com/api/v2/ -InstallationPolicy Trusted

# I also add the Trusted switch
Register-PackageSource -Name Nuget -Location "http://www.nuget.org/api/v2" –ProviderName Nuget -Trusted


### ONEUI -- Microsoft PACKAGE-MANAGEMENT

 Get-PackageProvider # -Shows package providers installed on your machine)
 Find-PackageProvider # -Find online package providers you can pull down and install)
 Get-PackageSource # -List all package sources, with its provider name)
 Register-PackageSource # -Register new package source for a provider)

 CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Cmdlet          Find-Package                                       1.4.8.1    PackageManagement
Cmdlet          Find-PackageProvider                               1.4.8.1    PackageManagement
Cmdlet          Get-Package                                        1.4.8.1    PackageManagement
Cmdlet          Get-PackageProvider                                1.4.8.1    PackageManagement
Cmdlet          Get-PackageSource                                  1.4.8.1    PackageManagement
Cmdlet          Import-PackageProvider                             1.4.8.1    PackageManagement
Cmdlet          Install-Package                                    1.4.8.1    PackageManagement
Cmdlet          Install-PackageProvider                            1.4.8.1    PackageManagement
Cmdlet          Register-PackageSource                             1.4.8.1    PackageManagement
Cmdlet          Save-Package                                       1.4.8.1    PackageManagement
Cmdlet          Set-PackageSource                                  1.4.8.1    PackageManagement
Cmdlet          Uninstall-Package                                  1.4.8.1    PackageManagement
Cmdlet          Unregister-PackageSource                           1.4.8.1    PackageManagement