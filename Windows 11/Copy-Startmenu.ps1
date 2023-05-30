# Source start menu template
$startmenuTemplate = "\\server\repository\Windows\Startmenu win11\start2.bin"

# Get all user profile folders
$usersStartMenu = get-childitem -path "C:\Users\*\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"

# Cleanup all journal files that are older than given date
ForEach ($startmenu in $usersStartMenu) {
  Copy-Item -Path $startmenuTemplate -Destination $startmenu -Force
}
