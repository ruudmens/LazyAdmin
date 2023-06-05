# Remove the installed package for each user
Get-AppxPackage -AllUsers | Where-Object {$_.Name -like "*WebExperience*"} | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

# Remove the provisioned package for new users
$AppxRemoval = Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*WebExperience*"} 
ForEach ( $App in $AppxRemoval) {
    Remove-AppxProvisionedPackage -Online -PackageName $App.PackageName 
}