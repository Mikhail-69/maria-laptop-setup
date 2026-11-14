<#
    Post-install automation for the Windows 11 virtual machine.
    Run inside Windows (PowerShell as Administrator):

        Set-ExecutionPolicy Bypass -Scope Process -Force
        .\post-install.ps1

    Installs: Microsoft 365 (Office), Visio, Visual Studio Community
    (both .NET desktop and C++ desktop workloads), 7-Zip, Chrome.
    Office and Visio are activated later by signing in to Microsoft 365.
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Test-Winget {
    return $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
}

Write-Host '== Checking winget =='
if (-not (Test-Winget)) {
    Write-Host 'winget is missing, installing App Installer from the Microsoft Store...'
    Start-Process 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1'
    throw 'Install "App Installer" from the Store, then run this script again.'
}

Write-Host '== Installing base tools =='
winget install --id 7zip.7zip -e --accept-source-agreements --accept-package-agreements
winget install --id Google.Chrome -e --accept-source-agreements --accept-package-agreements
winget install --id Microsoft.PowerToys -e --accept-source-agreements --accept-package-agreements

Write-Host '== Installing Visual Studio Community (both workloads) =='
$vsArgs = @(
    '--quiet', '--wait', '--norestart',
    '--add', 'Microsoft.VisualStudio.Workload.ManagedDesktop',
    '--add', 'Microsoft.VisualStudio.Workload.NativeDesktop',
    '--includeRecommended'
) -join ' '
winget install --id Microsoft.VisualStudio.2022.Community -e --override $vsArgs `
    --accept-source-agreements --accept-package-agreements

Write-Host '== Installing Microsoft 365 and Visio via Office Deployment Tool =='
$odtDir = 'C:\ODT'
New-Item -ItemType Directory -Force -Path $odtDir | Out-Null
$odtUrl = 'https://officecdn.microsoft.com/pr/wsus/setup.exe'
$odtExe = Join-Path $odtDir 'odt.exe'
Invoke-WebRequest -Uri $odtUrl -OutFile $odtExe
Start-Process -FilePath $odtExe -ArgumentList "/extract:$odtDir" -Wait

$config = Join-Path $odtDir 'configuration.xml'
@'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="ru-ru" />
      <Language ID="en-us" />
    </Product>
    <Product ID="VisioProRetail">
      <Language ID="ru-ru" />
      <Language ID="en-us" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Updates Enabled="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@ | Set-Content -Path $config -Encoding UTF8

$setup = Join-Path $odtDir 'setup.exe'
Start-Process -FilePath $setup -ArgumentList "/configure `"$config`"" -Wait

Write-Host ''
Write-Host 'Done. Remaining manual steps:'
Write-Host '  1. Sign in to Microsoft 365 to activate Office and Visio.'
Write-Host '  2. Activate Windows with your product key.'
Write-Host '  3. Sign in to Visual Studio (free Community licence).'
