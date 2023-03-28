<#
.SYNOPSIS
  Small script to install printer locally
.DESCRIPTION
  Install a local or network printer including the dirver and printerport
.NOTES
  Version:        1.0
  Author:         R. Mens
  Creation Date:  28 march 2023
  Purpose/Change: Initial script development
#>

$driverPath = "z:\drivers\brother\brimi16a.inf"
$driverName = "Brother MFC-J6945DW Printer"
$printerName = "Lazy Printer"
$printerPort = "10.0.2.200"
$printerPortName = "TCPPort:10.0.2.200"

# Check if driver is not already installed
if ($null -eq (Get-PrinterDriver -name $driverName)) {
  # Add the driver to the Windows Driver Store
  pnputil.exe /a $driverPath

  # Install the driver
  Add-PrinterDriver -Name $driverName
} else {
  Write-Warning "Printer driver already installed"
}

# Check if printerport doesn't exist
if ($null -eq (Get-PrinterPort -name $printerPortName)) {
  # Add printerPort
  Add-PrinterPort -Name $printerPortName -PrinterHostAddress $printerPort
} else {
  Write-Warning "Printer port with name $($printerPortName) already exists"
}

try {
  # Add the printer
  Add-Printer -Name printerName -DriverName $driverName -PortName $printerPortName
} catch {
  Write-Host $_.Exception.Message -ForegroundColor Red
}