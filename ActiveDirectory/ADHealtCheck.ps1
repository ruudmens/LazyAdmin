
<#
.Synopsis
  Checks the health of all domain controllers

.DESCRIPTION
  This script will get all domain controllers from your domain, and run a series of tests
  on each of them. 

  Read the linked blog article for the full details of the script.

.NOTES
  Name: Domain Controller Health 
  Author: R. Mens - LazyAdmin.nl
  Version: 1.3
  DateCreated: Oct 2023
  Purpose/Change: 
    - Fix line 148

.LINK
  https://lazyadmin.nl
#>

# Set variables
$reportDate = Get-Date -Format "dd-MM-yyyy"
$reportFileName = "LazyDCHealthCheck-$reportDate.html"
$reportPath = "c:\"
$outputToConsole = $true
$outputToHtml = $false

# Scripts needs to be run on a domain controller
If (-not (Get-CimInstance -Query "SELECT * FROM Win32_OperatingSystem where ProductType = 2")) {
    write-host "The scripts needs to be run on a domain controller." -ForegroundColor red
    break
}

# Check DNS configuration 
Function Get-DCDNSConfiguration($computername) {

    $DNSResult = "Success"

    try {
        $ipAddressDC = Resolve-DnsName $computername -Type A -ErrorAction Stop | select -ExpandProperty IPAddress 
    }
    catch [exception] {
        $DNSResult = "Failed"
        $DNSResultReason = "DNS record of host not found"
    }

    # Check DNS Server configuration
    $activeNetAdapter = Get-NetAdapter -CimSession $computername | Where {$_.Status -eq 'Up'} | select -ExpandProperty InterfaceIndex
    $DnsServers = Get-DnsClientServerAddress -CimSession $computername -InterfaceIndex $activeNetAdapter | select -ExpandProperty ServerAddresses

    if ($DnsServers[0] -contains $ipAddressDC -or $DnsServers[0] -eq "127.0.0.1" -or $DnsServers[0] -eq "::0") {
        $DNSResult = "Failed"
        $DNSResultReason = "Incorrect DNS server configured"
        $DNSResultLink = "https://lazyadmin.nl/it/add-domain-controller-to-existing-domain/#configure-dns-servers"
    }

    return $DNSResult, $DNSResultReason, $DNSResultLink
}

# Test the latency to the domain controller
Function Test-DCPing ($computername) {

    if ($Host.Version.Major -ge 7) {
        $latency = Test-Connection -ComputerName $computername -Count 1 -ErrorAction SilentlyContinue | 
        Select -ExpandProperty latency
    }else{
        $latency = Test-Connection -ComputerName $computername -Count 1 -ErrorAction SilentlyContinue | 
        Select -ExpandProperty ResponseTime
    }

    if ($null -eq $latency) {
        $pingResult = "Failed"
        $pingReason = "Unable to ping DC"
    }elseif($latency -gt 100) {
        $pingResult = "Warning"
        $pingReason = "High latency ($latency (ms))"
    }else{
        $pingResult = "Success - $latency (ms)"
    }

    return $pingResult, $pingReason
}

# Get the uptime of the DC in hour or days
Function Get-DCUpTime($computername) {

    try {
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem -ComputerName $computername).LastBootupTime
    }
    catch [exception] {
        $uptimeResult = "Failed"
        $uptimeReason = "Unable to retrieve system uptime"

        return $uptimeResult, $uptimeReason
    }
    
    if ($uptime.TotalHours -lt 100 ) {
        $uptimeResult = [Math]::Round(($uptime | Select -ExpandProperty TotalHours),0,[MidPointRounding]::AwayFromZero)
        $uptimeResult = [string]$uptimeResult + " hrs"

        if ($uptime.TotalHours -lt 24 ) {
            $uptimeReason = "Only running for $uptimeResult"
            $uptimeResult = "Warning"
        }
    }else{
        $uptimeResult = [Math]::Round(($uptime | Select -ExpandProperty TotalDays),0,[MidPointRounding]::AwayFromZero)
        $uptimeResult = [string]$uptimeResult + " days"
    }
    
    return $uptimeResult, $uptimeReason
}

Function Get-FSMORoles{
    [cmdletbinding()]
    Param(
        [parameter(Mandatory=$true)]
        [System.Object]$dc,
        [parameter(Mandatory=$false)]
        [bool]$fsmoCheckPassed
    )
    if (!$fsmoCheckPassed) {
        if ($dc.OperationMasterRoles.count -eq 5) {
            $FSMOResult = "Success - $($dc.OperationMasterRoles -join, ' ')"
            $fsmoCheckPassed = $true
        }elseif($dc.OperationMasterRoles.count -gt 0){
            $FSMOResult = $null
            $FSMOReason = $dc.OperationMasterRoles  -join ", "
        }else{
            $forestInfo = Get-ADForest $dc.domain | Select SchemaMaster, DomainNamingMaster
            $domainInfo = Get-ADDomain $dc.domain | Select PDCEmulator, RIDMaster, InfrastructureMaster

            
            $combinedInfo = [PSCustomObject]@{
                SchemaMaster = $forestInfo.SchemaMaster
                DomainNamingMaster = $forestInfo.DomainNamingMaster
                PDCEmulator = $domainInfo.PDCEmulator
                RIDMaster = $domainInfo.RIDMaster
                InfrastructureMaster = $domainInfo.InfrastructureMaster
            }

            $combinedInfo.PSObject.Properties | Foreach {
                If ($_.Value -ne $dc.hostname) {
                    if (!(Test-Connection -ComputerName $_.Value -Count 1 -Quiet -ErrorAction SilentlyContinue)) {
                        $FSMOResult = "Failed"
                        $FSMOReason = "Unable to reach $($_.key) - $($_.Value)"
                    }
                }
            }
        }
        return $FSMOResult, $FSMOReason, $fsmoCheckPassed
    }else{
        return $null
    }
}

# Check the free space on the OS Drive
Function Get-FreeSpaceOS ($computername) {

    # Get the system drive (commonly this is the c: drive)
    # To optimize the script you can also remove the Get-CimInstance and replace it with c:
    try {
        $systemDrive = (Get-CimInstance -Computername $computername Win32_OperatingSystem | Select -ExpandProperty SystemDrive).Trim(":")

        $freeSpace = [Math]::Round(((Get-Volume -CimSession $computername -DriveLetter $systemDrive).SizeRemaining / 1GB),2)

        if ($freeSpace -gt '5' -and $freeSpace -lt 10) {
            $freeSpaceResult = "Warning"
            $freeSpaceReason = "Only $($freeSpace) Gb available"
        }elseif ($freeSpace -lt '6') {
            $freeSpaceResult = "Error"
            $freeSpaceReason = "Only $($freeSpace) Gb available"
        }
        else{
            $freeSpaceResult = "$freeSpace Gb"
        }

        return $freeSpaceResult, $freeSpaceReason
    } catch {
        return "Error", "Unable to retrieve free space information: $_"
    }
}

# Get Active Directory DB Size
Function Get-ADDatabaseSize() {
    try {
        $DSADbFile = Get-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\NTDS\Parameters | Select 'DSA Database File'
        $DSADbFileSize = (Get-ItemProperty -Path $DSADbFile.'DSA Database File').Length /1GB
    }
    catch [exception] {
        $DSADbFileSizeResult = "Failed"
        $DSADbFileSizeReason = 'Unable to retrieve'
    }

    $DSADbFileSizeResult = [Math]::Round($DSADbFileSize,2,[MidPointRounding]::AwayFromZero)

    return $DSADbFileSizeResult, $DSADbFileSizeReason
}

# Check if the NTDS, ADWS, DNS, DNScache, KDC, Netlogon and W32Time services are running
Function Get-DCServices($computername) {

    $services = @(
        'EventSystem',
        'RpcSs',
        'IsmServ',
        'ntds', 
        'adws', 
        'dns', 
        'dnscache', 
        'kdc',
        'LanmanServer',
        'LanmanWorkstation'
        'SamSs'
        'w32time', 
        'netlogon'
        )

    $stoppedServices = Invoke-Command -Computername $computername -ScriptBlock {Get-Service -Name $using:services | where {$_.Status -eq 'Stopped'}}

    if ($stoppedServices.length -gt 0) {
        $servicesResults = "Failed"
        $stoppedServicesNames = $stoppedServices.Name -join ', '
        $servicesReason = "$stoppedServicesNames not running"
    }else{
        $servicesResults = "Success"
    }

    return $servicesResults,$servicesReason
}

# Run DCDiag tests
# Note : Test may fail if your OS is not in English. Needs different patterns depening on Local Culture
# Based on : httpNew-s://www.powershellbros.com/using-powershell-perform-dc-health-checks-dcdiag-repadmin/
function Get-DCDiagResults($computername) {
    # Skips services, we already checked them
    $DcdiagOutput = Invoke-Command -Computername $computername -ScriptBlock {Dcdiag.exe /skip:services}
    
    if ($DcdiagOutput) {
        $Results = New-Object PSCustomObject
    
        $DcdiagOutput | ForEach-Object {
            switch -Regex ($_) {
                "Starting" {
                    $TestName = ($_ -replace ".*Starting test: ").Trim()
                }
                "passed test|failed test" {
                    $TestStatus = if ($_ -match "passed test") { "Passed" } else { "Failed" }
                }
            }
    
            if ($null -ne $TestName -and $null -ne $TestStatus) {
                $Results | Add-Member -Name $TestName.Trim() -Value $TestStatus -Type NoteProperty -Force
                $TestName = $null
                $TestStatus = $null
            }
        }
    }
    return $Results
}

function Get-ReplicationData($computername) {
    $repPartnerData = Get-ADReplicationPartnerMetadata -Target $computername

    $replResult = @{}

    # Get the replication partner
    $replResult.repPartner = ($RepPartnerData.Partner -split ',')[1] -replace 'CN=', '';

    # Last attempt
    try {
        $replResult.lastRepAttempt = @()
        $replLastRepAttempt = $repPartnerData.LastReplicationAttempt
        $replFrequency = (Get-ADReplicationSiteLink -Filter *).ReplicationFrequencyInMinutes
        if (((Get-Date) - $replLastRepAttempt).Minutes -gt $replFrequency) {
            $replResult.lastRepAttempt += "Warning"
            $replResult.lastRepAttempt += "More then $replFrequency minutes ago - $($replLastRepAttempt.ToString('yyyy-MM-dd HH:mm'))"
        }else{
            $replResult.lastRepAttempt += "Success - $($replLastRepAttempt.ToString('yyyy-MM-dd HH:mm'))"
        }

        # Last successfull replication
        $replResult.lastRepSuccess = @()
        $replLastRepSuccess = $repPartnerData.LastReplicationSuccess
        if (((Get-Date) - $replLastRepSuccess).Minutes -gt $replFrequency) {
            $replResult.lastRepSuccess += "Warning"
            $replResult.lastRepSuccess += "More then $replFrequency minutes ago - $($replLastRepSuccess.ToString('yyyy-MM-dd HH:mm'))"
        }else{
            $replResult.lastRepSuccess += "Success - $($replLastRepSuccess.ToString('yyyy-MM-dd HH:mm'))"
        }

        # Get failure count
        $replResult.failureCount = @()
        $replFailureCount = (Get-ADReplicationFailure -Target $computername).FailureCount
        if ($null -eq $replFailureCount) { 
            $replResult.failureCount += "Success"
        }else{
            $replResult.failureCount += "Failed"
            $replResult.failureCount += "$replFailureCount failed attempts"
        }

        # Get replication results
        $replDelta = (Get-Date) - $replLastRepAttempt

        # Check if the delta is greater than 180 minutes (3 hours)
        if ($replDelta.TotalMinutes -gt $replFrequency) {
            $replResult.delta += "Failed"
            $replResult.delta += "Delta is more then 180 minutes - $($replDelta.Minutes)"
        }else{
            $replResult.delta += "Success - $($replDelta.Minutes) minutes"
        }
    }
    catch [exception]{
        $replResult.lastRepAttempt += "Failed"
        $replResult.lastRepAttempt += "Unable to retrieve replication data"
        $replResult.lastRepSuccess += "Failed"
        $replResult.lastRepSuccess += "Unable to retrieve replication data"
        $replResult.failureCount += "Failed"
        $replResult.failureCount += "Unable to retrieve replication data"
        $replResult.delta += "Failed"
        $replResult.delta += "Unable to retrieve replication data"
    }

    return $replResult
}

function Get-TimeDifference($computername) {
    # credits: https://stackoverflow.com/a/63050189
    $currentTime, $timeDifference = (& w32tm /stripchart /computer:$computername /samples:1 /dataonly)[-1].Trim("s") -split ',\s*'
    $diff = [double]$timeDifference

    if ($diff -ge 1) {
        $timeResult = "Failed"
        $timeReason = "Offset greater then 1"
    }else{
        $diffRounded = [Math]::Round($diff,4,[MidPointRounding]::AwayFromZero)
        $timeResult = "Success - $diffRounded"
    }
    return $timeResult, $timeReason
}

# Format the results
function Write-HostColored{
    [cmdletbinding()]
    Param(
        [parameter(Mandatory=$true)]
        $label,
        [parameter(Mandatory=$false)]
        $status
    )

    if ($status -is [array]) {
        if ($status[0] -contains 'Failed' -or $status[0] -contains 'Error') {
            Write-Host ("{0,-31} : " -f $label) -NoNewline
            Write-Host "Failed <--------- $($status[1])" -ForegroundColor red
        }
        elseif ($status[0] -contains 'Warning') {
            Write-Host ("{0,-31} : " -f $label) -NoNewline
            Write-Host "Warning <--------- $($status[1])" -ForegroundColor Yellow
        }
        else {
            Write-Host ("{0,-31} : " -f $label) -NoNewline
            Write-Host $status[0] -ForegroundColor green
        }
    }elseif($status -is [PSCustomObject]) {
        # Can only be DCDiag test for now...
        $dcDiagFailedCount = 0
        $dcdiagPassed = 0

        $status.PSObject.Properties | ForEach {
            if ($_.value -eq 'Failed') {
                Write-Host ("{0,-31} : " -f "DCDiag - $($_.name)") -NoNewline
                Write-Host $_.value -ForegroundColor red
                $dcDiagFailedCount++
            }else{
                $dcdiagPassed++
            }
        }

        if ($dcDiagFailedCount -gt 0) {
            Write-Host ("{0,-31} : " -f "DCDiag - Other tests ($dcdiagPassed)") -NoNewline
            Write-Host "Passed" -ForegroundColor green
        }else{
            Write-Host ("{0,-31} : " -f "DCDiag - All tests") -NoNewline
            Write-Host "Passed" -ForegroundColor green
        }
    }else{
        if ($status -like 'Success*') {
            Write-Host ("{0,-31} : " -f $label) -NoNewline
            Write-Host $status -ForegroundColor Green
        }else {
            Write-Host ("{0,-31} : " -f $label) -NoNewline
            Write-Host $status -ForegroundColor White
        }
    }
}
# Prepare for the DC tests
$allDomainControllers = @()
$allDomainControllers = Get-ADDomainController -filter * | Select-Object name
$errorCount = 0
$warningCount = 0
$dcResults = @()
$fsmoResult = $false

ForEach ($domainController in $allDomainControllers) {
    $dc = Get-ADDomainController -Server $domainController.name

    # Create a PS Custom object for the results
    $currentDC = [PSCustomObject]@{
        "HostName" = $null
        "OS" = $null
        "OS Version" = $null
        "IP Address" = $null
        "FMSO Roles" = $null
        "Ping" = $null
        "DNS" = $null
        "Uptime" = $null
        "OS Free Space (Gb)" = $null
        "AD DB Size (Gb)" = $null
        "Services running" = $null
        "DCDIAG" = $null
        "Replication Partner" = $null
        "Replication Last attempt" = $null
        "Replication Last success" = $null
        "Replication Delta" = $null
        "Time offset" = $null
    }

    # Get replication data
    $repData = Get-ReplicationData -computername $dc.Hostname

    # Get FSMO Roles
    $fsmo = Get-FSMORoles -dc $dc -fsmoCheckPassed $fsmoResult
    $fsmoResult = if ($fsmo.length -gt 1) {$fsmo[2]}

    # Populate the properties with the test results
    $currentDC."HostName" = ($dc.HostName).ToLower()
    $currentDC."OS" = $dc.OperatingSystem
    $currentDC."OS Version" = $dc.OperatingSystemVersion
    $currentDC."Ip Address" = $dc.IPv4Address
    $currentDC."FMSO Roles" = if ($fsmo.length -gt 1) {$fsmo[0], $fsmo[1]} else {$fsmo}
    $currentDC."DNS" = Get-DCDNSConfiguration -computername $dc.HostName
    $currentDC."Ping" = Test-DCPing -computername $dc.HostName
    $currentDC."Uptime" = Get-DCUpTime -computername $dc.HostName
    $currentDC."OS Free Space (Gb)" =  Get-FreeSpaceOS -computername $dc.HostName
    $currentDC."AD DB Size (Gb)" = Get-ADDatabaseSize
    $currentDC."Services running" = Get-DCServices -computername $dc.HostName
    $currentDC."DCDIAG" = Get-DCDiagResults -computername $dc.HostName
    $currentDC."Replication Partner" = $repData.repPartner
    $currentDC."Replication Last attempt" = $repData.lastRepAttempt
    $currentDC."Replication Last success" = $repData.lastRepSuccess
    $currentDC."Replication Delta" = $repData.delta
    $currentDC."Time offset" = Get-TimeDifference -computername $dc.HostName

    $dcResults += $currentDC
}

$outputToConsole = $true
if ($outputToConsole) {
    foreach ($dc in $dcResults) {
        $dc.PSObject.Properties | ForEach {Write-HostColored -label $_.name -status $_.value}

        Write-Host "`n ------------------------------- `n"
    }

    $errorCount = ($dcResults | ForEach-Object {
        $_.PSObject.Properties.Value | Where-Object { $_ -match "Failed" }
    }).Count

    # Display alert summary
    if ($errorCount -gt 0) {
        Write-Host "Summary: $errorCount Error(s) Detected"
    }
    else {
        Write-Host "Summary: No Errors Detected"
    }

    $warningCount = ($dcResults | ForEach-Object {
        $_.PSObject.Properties.Value | Where-Object { $_ -match "Warning" }
    }).Count

    # Display alert warning
    if ($warningCount -gt 0) {
        Write-Host "Summary: $warningCount Warning(s) Detected"
    }
    else {
        Write-Host "Summary: No Warnings Detected"
    }
}

$outputToHtml = $true
if ($outputToHtml) {
    $htmlTable = "
    <style>
        table {
            border-collapse: collapse;
            width: 100%;
            font-family: system-ui;
            font-size: 12px;
        }

        th, td {
            text-align: left;
            padding: 8px;
            max-width:200px;
        }

        th {
            background-color: #fff;
            color: #05668D;
            text-transform:uppercase;
        }

        tr:nth-child(even) {
            background-color: #fafafa;
        }

        .failed {
            background-color: #e74c3c;
            color: white;
        }

        .warning {
            background-color: #f1c40f;
        }

        .success {
            background-color: #679436;
            color: white;
        }
        .dcdiag-table{
            margin:-8px;
        }
        .dcdiag-table td{
            padding:5px;
        }
        .dcdiag-failed {
            color: #e74c3c;
            font-weight:bold;
        }
        .dcdiag-success {
            color: #679436;
            font-weight:bold;
        }
    </style>
    
    "
    if ($allDomainControllers.length -gt 2) {
        # When we have more then two dc's, display the results horizontal.
        $htmlTable += "
        <table border='1'>
        <tr><th>Server</th>"

        # Create header row with property labels
        $properties = $dcResults[0].PSObject.Properties
        foreach ($property in $properties) {
            if ($property.Name -ne 'HostName') {
                $htmlTable += "<th><strong>$($property.Name)</strong></th>"
            }
        }
        $htmlTable += "</tr>"

        # Create rows for each server
        foreach ($dc in $dcResults) {
            $htmlTable += "<tr>"
            
            # Add the server name in the first column
            $htmlTable += "<td>$($dc.HostName)</td>"

            foreach ($property in $properties) {
                if ($property.Name -ne 'HostName') {

                    if ($property.Name -eq "DCDIAG") {
                        # If the property is DCDIAG, create a table inside a cell for each server
                        $dcdiagTable = "<table border='0' class='dcdiag-table'>"
                        $dcdiagPassed = 0

                        $dc.DCDIAG.PSObject.Properties | foreach{
                            if ($_.value -contains 'failed') {
                                $dcdiagTable += "<tr><td>$($_.name)</td><td class='dcdiag-failed'>$($_.value)</td></tr>"
                            }else{
                                $dcdiagPassed++
                            }
                        }
                        $dcdiagTable += "<tr><td>Others ($dcdiagPassed)</td><td class='dcdiag-success'>Passed</td></tr>"
                        $dcdiagTable += "</table>"
                        $htmlTable += "<td>$dcdiagTable</td>"
                    } else {
                        # Add the value of the current property in subsequent columns
                        # Skip hostname in HTML Output
                        $value = $dc.$($property.Name)
                        $statusCell = ""
                        if ($null -ne $value) {
                            if ($value -match "Failed") {
                                $statusCell = "<td class='failed'>$value</td>"
                            } elseif ($value -match "Warning") {
                                $statusCell = "<td class='warning'>$value</td>"
                            } elseif ($value -match "Success") {
                                $value = "$($value)".replace("Success - ","")
                                $statusCell = "<td class='success'>$value</td>"
                            } else {
                                $statusCell = "<td>$value</td>"
                            }
                        } else {
                            $statusCell = "<td>$value</td>"
                        }

                        $htmlTable += $statusCell
                    }
                }
            }
            $htmlTable += "</tr>"
        }

        # Close the table
        $htmlTable += "</table>"
    }else{
        $htmlTable += "<table border='0'>"

        # When we only have one or two dc's, then display the results vertical.
        # Create the header row
        $htmlTable += "<tr><th></th>"
        foreach ($dc in $dcResults) {
            $htmlTable += "<th>$($dc.HostName)</th>"
        }
        $htmlTable += "</tr>"

        # Create rows with labels and properties
        $properties = $dcResults[0].PSObject.Properties

        foreach ($property in $properties) {
            $htmlTable += "<tr>"
            # Add the label for the property in the first column
            if ($property.Name -ne 'Hostname') {
                $htmlTable += "<td><strong>$($property.Name)</strong></td>"

                foreach ($dc in $dcResults) {
                    if ($property.Name -eq "DCDIAG") {
                        # If the property is DCDIAG, create a table inside a cell for each server
                        $dcdiagTable = "<table border='0'>"
                        $dcdiagPassed = 0
                        $dc.DCDIAG.PSObject.Properties | foreach{
                            if ($_.value -contains 'failed') {
                                $dcdiagTable += "<tr><td>$($_.name)</td><td class='dcdiag-failed'>$($_.value)</td></tr>"
                            }else{
                                $dcdiagPassed++
                            }
                        }
                        $dcdiagTable += "<tr><td>Others ($dcdiagPassed)</td><td class='dcdiag-success'>Passed</td></tr>"
                        $dcdiagTable += "</table>"
                        $htmlTable += "<td>$dcdiagTable</td>"
                    } else {
                        # Add the value of the current result in subsequent columns
                        # Skip hostname in HTML Output
                        $value = $dc.$($property.Name)
                        $statusCell = ""

                        if ($value -match "Failed") {
                            $statusCell = "<td class='failed'>$value</td>"
                        } elseif ($value -match "Warning") {
                            $statusCell = "<td class='warning'>$value</td>"
                        } elseif ($value -match "Success") {
                            $value = "$($value)".replace("Success - ","")
                            $statusCell = "<td class='success'>$value</td>"
                        } else {
                            $statusCell = "<td>$value</td>"
                        }
                        $htmlTable += $statusCell
                    }
                    
                }
                $htmlTable += "</tr>"
            }
        }

        # Close the table
        $htmlTable += "</table>"
    }

    # Save the HTML to a file or display it
    $path = $reportPath + $reportFileName
    
    $htmlTable | Out-File -FilePath $path -Encoding UTF8
}