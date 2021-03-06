<#
.SYNOPSIS
    Bootstrap for package building

.DESCRIPTION
    Installs required software and builds package
#>

# http://www.leeholmes.com/blog/2008/07/30/workaround-the-os-handles-position-is-not-what-filestream-expected/
# http://stackoverflow.com/questions/8978052/powershell-2-0-redirection-file-handle-exception
function savepowershellfromitself {
    $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
    $objectRef = $host.GetType().GetField( "externalHostRef", $bindingFlags ).GetValue( $host )
    $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetProperty"
    $consoleHost = $objectRef.GetType().GetProperty( "Value", $bindingFlags ).GetValue( $objectRef, @() )
    [void] $consoleHost.GetType().GetProperty( "IsStandardOutputRedirected", $bindingFlags ).GetValue( $consoleHost, @() )
    $bindingFlags = [Reflection.BindingFlags] "Instance,NonPublic,GetField"
    $field = $consoleHost.GetType().GetField( "standardOutputWriter", $bindingFlags )
    $field.SetValue( $consoleHost, [Console]::Out )
    $field2 = $consoleHost.GetType().GetField( "standardErrorWriter", $bindingFlags )
    $field2.SetValue( $consoleHost, [Console]::Out )
}

savepowershellfromitself

# Ensure we can find wix tools
$env:Path += ";C:\Program Files (x86)\WiX Toolset v3.10\bin"

$DotNetUpgradeURL = "https://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe"
$Powershell3URL = "https://download.microsoft.com/download/E/7/6/E76850B8-DA6E-4FF5-8CCE-A24FC513FD16/Windows6.1-KB2506143-x64.msu"
$BuildToolsURL = "https://download.microsoft.com/download/E/E/D/EEDF18A8-4AED-4CE0-BEBE-70A83094FC5A/BuildTools_Full.exe"
$WixURL = "http://download-codeplex.sec.s-msft.com/Download/Release?ProjectName=wix&DownloadId=1587179&FileTime=131118854865270000&Build=21031"
$SubstrateURL = "https://s3.amazonaws.com/hc-ops/vagrant-substrate/substrate_windows_x64.zip"

$TmpDir = [System.IO.Path]::GetTempPath()

$DotNetUpgradeDestination = [System.IO.Path]::Combine($TmpDir, "dotnet-upgrade.exe")
$Powershell3Destination = [System.IO.Path]::Combine($TmpDir, "powershell-upgrade.msu")
$BuildToolsDestination = [System.IO.Path]::Combine($TmpDir, "build.exe")
$WixDestination = [System.IO.Path]::Combine($TmpDir, "wix.exe")
$SubstrateDestination = [System.IO.Path]::Combine($TmpDir, "substrate_windows_x64.zip")

$WebClient = New-Object System.Net.WebClient

# Check if proxy is available and configure if found
$TestSocket = New-Object Net.Sockets.TcpClient
$ErrorActionPreference = 'SilentlyContinue'
$TestSocket.Connect('192.168.1.1', 8123)
$ErrorActionPreference = 'Continue'
if($TestSocket.Connected) {
  $TestSocket.Close()
  Write-Host "HTTP proxy detected. Enabling."
  $Proxy = New-Object System.Net.WebProxy("http://192.168.1.1:8123", $true)
  $WebClient.proxy = $Proxy
  $env:http_proxy="http://192.168.1.1:8123"
  $ProxyArgs = @("winhttp", "set", "proxy", "http://192.168.1.1:8123")
  netsh winhttp set proxy 192.168.1.1:8123
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
  Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "http://192.168.1.1:8123"
}
$TestSocket = $null

$WixHeat = Get-Command heat

if(!$WixHeat){
  Write-Host "Required packaging setup not detected. Installing."

#  Write-Host "Downloading .net framework upgrade."
#  $WebClient.DownloadFile($DotNetUpgradeURL, $DotNetUpgradeDestination)
#  Write-Host ".net framework upgrade successfully downloaded."
#  Write-Host "Downloading Powershell 3 upgrade."
#  $WebClient.DownloadFile($Powershell3URL, $Powershell3Destination)
#  Write-Host "Powershell 3 upgrade successfully downloaded."
#  Write-Host "Downloading Windows Build Tools."
#  $WebClient.DownloadFile($BuildToolsURL, $BuildToolsDestination)
#  Write-Host "Windows Build Tools successfully downloaded."
  Write-Host "Downloading Wix toolset."
  $WebClient.DownloadFile($WixURL, $WixDestination)
  Write-Host "Wix toolset successfully downloaded."

  Set-ExecutionPolicy bypass
  $env:SEE_MASK_NOZONECHECKS=1

#  $DotNetUpgradeInstallArgs = @("/norestart", "/q")
#  Write-Host "Installing .net framework upgrade."
#  $DotNetUpgradeProcess = Start-Process -FilePath $DotNetUpgradeDestination -ArgumentList $DotNetUpgradeInstallArgs -Wait -PassThru

#  $Powershell3UpgradeArgs = @($Powershell3Destination, "/quiet", "/norestart")
#  Write-Host "Installing Powershell 3 upgrade."
#  $PowerShell3Process = Start-Process -FilePath wusa -ArgumentList $Powershell3UpgradeArgs -Wait -PassThru

#  $BuildToolsInstallArgs = @("/NoRefresh", "/NoRestart", "/NoWeb", "/Quiet", "/Full")
#  Write-Host "Installing Windows Build Tools."
#  $BuildToolsProcess = Start-Process -FilePath $BuildToolsDestination -ArgumentList $BuildToolsInstallArgs -Wait -PassThru

  $WixInstallArgs = @("/quiet", "/norestart")
  Write-Host "Installing Wix toolset."
  $WixProcess = Start-Process -FilePath $WixDestination -ArgumentList $WixInstallArgs -Wait -PassThru

#  Write-Host "!!!!!!!!!!!!!!!!!!!!! NOTICE !!!!!!!!!!!!!!!!!!!!!"
#  Write-Host "! This box is now configured to package Vagrant  !"
#  Write-Host "! A reboot is required before proceeding. Please !"
#  Write-Host "! reload this instance and re-provision to build !"
#  Write-Host "! the Windows package                            !"
#  Write-Host "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
# } else {
}
[System.IO.Directory]::CreateDirectory("C:\vagrant\substrate-assets") | Out-Null
[System.IO.Directory]::CreateDirectory("C:\vagrant\pkg") | Out-Null

$SubstratePath = "C:\vagrant\substrate-assets\substrate_windows_x64.zip"
$SubstrateExists = Test-Path -LiteralPath $SubstratePath

if(!$SubstrateExists){
  Write-Host "Downloading windows substrate for package build."
  $WebClient.DownloadFile($SubstrateURL, $SubstrateDestination)
  Move-Item $SubstrateDestination, $SubstratePath
}
Write-Host "Starting package build"
Set-Location -Path C:\vagrant\pkg

$SignKeyPath = "C:\vagrant\Win_CodeSigning.p12"
$SignKeyExists = Test-Path -LiteralPath $SignKeyPath
if($SignKeyExists){
  if(!$env:SignKeyPassword){
    Write-Host "Error: No password provided for code signing key!"
    exit 1
  }
  savepowershellfromitself
  Invoke-Expression "C:\vagrant\package\package.ps1 -SubstratePath ${SubstratePath} -VagrantRevision master -SignKey ${SignKeyPath} -SignKeyPassword ${env:SignKeyPassword} -SignPath 'C:\Program Files\Microsoft SDKs\Windows\v7.1\Bin\signtool.exe'"
} else {
  savepowershellfromitself
  Invoke-Expression "C:\vagrant\package\package.ps1 -SubstratePath ${SubstratePath} -VagrantRevision master"
}