$ErrorActionPreference = "Continue"
##Start Logging to %TEMP%\intune.log
$date = get-date -format yyyyMMddTHHmmssffff
Start-Transcript -Path C:\Temp\intune-$date.log

#Install MS Graph if not available


Write-Host "Installing Microsoft Graph modules if required (current user scope)"

#Install MS Graph if not available
if (Get-Module -ListAvailable -Name Microsoft.Graph.authentication) {
    Write-Host "Microsoft Graph Already Installed"
} 
else {
    try { 
        Install-Module -Name Microsoft.Graph.authentication -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    }
    catch [Exception] {
        $_.message 
        exit
    }
}


# Load the Graph module
Import-Module microsoft.graph.authentication


##Connect to MS Graph
Select-MgProfile -Name Beta
Connect-MgGraph -Scopes DeviceManagementApps.ReadWrite.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access



##Grab all devices
$uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices"
$alldevices = (Invoke-MgGraphRequest -uri $uri -Method GET -OutputType PSObject).value

##Drop them into an array to save too many nested loops
$deviceids = @()

##Populate the array
foreach ($device in $alldevices) {
$deviceid = $device.id
$deviceids += $deviceid
}

##Create an array for the apps
$discoveredapps = @()

##Populate App array
foreach ($deviceapp in $deviceids) {

$uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$deviceapp')?`$expand=detectedApps"
$appsfound = (Invoke-MgGraphRequest -uri $uri -Method GET -OutputType PSObject).detectedApps
foreach ($app in $appsfound) {
$discoveredapps += $app.DisplayName
}
}

##Group the apps to get a count, sort and then display in GUI with drill-down
$appslist = $discoveredapps | group | select Count, Name | Sort-Object Count -Descending | Out-GridView -Title "Discovered Apps" -PassThru | ForEach-Object {
##App to search for
$appname = $_.Name

##Create an array of devices with the app installed in case we want to export-csv or GUI popup with this data at a later date
$deviceswithappinstalled = @()

##Loop through machines looking for the app
foreach ($findtheapp in $deviceids) {
$uri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$findtheapp')?`$expand=detectedApps"
$appsfound = (Invoke-MgGraphRequest -uri $uri -Method GET -OutputType PSObject).detectedApps
##App found, grab the devicename
if ($appsfound -match $appname) {
$deviceuri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices/$Aappsfound"
$devicename = (Invoke-MgGraphRequest -uri $uri -Method GET -OutputType PSObject).devicename
write-host "App $appname found on device $devicename ($findtheapp)"
$deviceswithappinstalled += $devicename
}
}
}

Stop-Transcript
