<#
    .SYNOPSIS
    This script could be used to install the latest Windows Terminal on Windows Server (Windows Server 2022 at least).

    .DESCRIPTION
    This script aims to install the latest version of Windows Terminal. It could install both Stable and Preview version.
    Windows Terminal can be installed for the current user or for all users on the system. 
    The package requires OS version 10.0.19041.0 or higher (Windows Server 2022 at least).
    The script could be used even to install Windows Terminal in air-gapped environment without internet.
    Parameters -DownloadOnly and -OfflineInstall should be used to download content beforehand and perform 
    offline installation later.

    .NOTES
    Name: Install-WindowsTerminal.ps1
    Author: @ahpooch
    Version: 1.0.2
    License: MIT
    DateModified: 07.21.2025

    Acknowledgement: Dave Tapley (JE Fuller) - davetapley/install-windows-terminal

    .PARAMETER Scope
    Could be one of: "CurrentUser", "AllUsers"

    .PARAMETER Preview
    If this switch parameter is present, the script will install the Preview version of Windows Terminal.

    .PARAMETER DownloadOnly
    If this switch parameter is present, the script will only download the required files (without installation).
    This is useful for installing Windows Terminal later in air-gapped environments.
    Files are saved to the directory where the script is executed.

    .PARAMETER OfflineInstall
    If this switch parameter is present, the script will install Windows Terminal using cached files in its directory.
    This is useful for air-gapped environments.

    .EXAMPLE 
    Installation of Windows Terminal for current user.
    PS> & .\Install-WindowsTerminal.ps1

    .EXAMPLE
    Installation of Windows Terminal for all users.
    PS> & .\Install-WindowsTerminal.ps1 -Scope AllUsers

    .EXAMPLE
    Installation of Windows Terminal Preview for current user.
    PS> & .\Install-WindowsTerminal.ps1 -Preview

    .EXAMPLE
    Installation of Windows Terminal Preview for all users.
    PS> & .\Install-WindowsTerminal.ps1 -Scope AllUsers -Preview
    
    .EXAMPLE
    Download files for Windows Terminal offline installation.
    PS> & .\Install-WindowsTerminal.ps1 -DownloadOnly

    .EXAMPLE
    Download files for Windows Terminal Preview offline installation.
    PS> & .\Install-WindowsTerminal.ps1 -Preview -DownloadOnly
    
    .EXAMPLE
    Installation of Windows Termianl for current user, using cached files in the script directory.
    PS> & .\Install-WindowsTerminal.ps1 -OfflineInstall

    .EXAMPLE
    Installation of Windows Terminal Preview for all users, using cached files in the script directory.
    PS> & .\Install-WindowsTerminal.ps1 -Scope AllUsers -Preview -OfflineInstall

    .INPUTS
    None.

    .OUTPUTS
    System.String.
    Install-WindowsTerminal.ps1 returns the installed Windows Terminal version and build.

    .LINK
    https://github.com/ahpooch/install-windows-terminal
#>
    
[CmdletBinding(DefaultParameterSetName = 'OnlineInstall')]
param(
    [Parameter(Mandatory = $false, ParameterSetName = 'OnlineInstall', Position = 0 )]
    [Parameter(Mandatory = $false, ParameterSetName = 'DownloadOnly', Position = 0 )]
    [Parameter(Mandatory = $false, ParameterSetName = 'OfflineInstall', Position = 0 )]
    [ValidateSet("CurrentUser", "AllUsers")]
    [string]$Scope = "CurrentUser",
    
    [Parameter(Mandatory = $false, ParameterSetName = 'DownloadOnly' )]
    [Parameter(Mandatory = $false, ParameterSetName = 'OfflineInstall' )]
    [Parameter(Mandatory = $false, ParameterSetName = 'OnlineInstall' )]
    [switch]$Preview,
    
    [Parameter(Mandatory = $false, ParameterSetName = 'DownloadOnly' )]
    [switch]$DownloadOnly,
    
    [Parameter(Mandatory = $false, ParameterSetName = 'OfflineInstall' )]
    [switch]$OfflineInstall
)

# Workaround for Powershell Core and Appx Module issue: https://github.com/PowerShell/PowerShell/issues/13138
if ($PSVersionTable.PSEdition -eq "Core") { & { $ProgressPreference = 'Ignore'; Import-Module Appx -UseWindowsPowerShell 3>$null } }

if ($Preview) {
    $Script:PackageName = "Microsoft.WindowsTerminalPreview"
    $Package = Get-AppxPackage -Name $Script:PackageName
}
else {
    $Script:PackageName = "Microsoft.WindowsTerminal"
    $Package = Get-AppxPackage -Name $Script:PackageName
}
if ($null -ne $Package -and -not $DownloadOnly) {
    Write-Host "$Script:PackageName is already installed."
    Write-Host "Remove $Script:PackageName if you want to install new version of it using this script."
    Write-Host "You could use command `'Get-AppxPackage $Script:PackageName | Remove-AppxPackage`' to remove it."
    exit
}

### Checking elevation if installing for all users.
Function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ($Scope -eq "AllUsers" -and !(Test-IsAdmin)) {
    Throw "Installation with '-Scope AllUsers' requires elevation!"
    exit
}

### Checking OS version and throwing an error if it is not compatible.
[version]$RequiredVersion = [version]"10.0.19041.0"
[version]$CurrentOSVersion = [version](Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Version)
if ($CurrentOSVersion -lt $RequiredVersion) {
    Throw "Cannot install the package because it is not compatible with this device. See https://github.com/microsoft/terminal/issues/2177.`nThe package requires OS version 10.0.19041.0 or higher (Windows Server 2022 at least). The device is currently running OS version $CurrentOSVersion"
    exit
}

### Setting variables for dependencies that don't change with each new Windows Terminal version.
# Microsoft.VCLibs.x64.14.00.Desktop.appx
$vclibs_x64_filename = "Microsoft.VCLibs.x64.14.00.Desktop.appx"
$vclibs_x64_url = "https://aka.ms/$vclibs_x64_filename"

#{Microsoft.UI.Xaml.2.8_8.2501.31001.0_x64__8wekyb3d8bbwe}
# Microsoft.UI.Xaml.2.8.x64.appx
$uixaml_x64_filename = "Microsoft.UI.Xaml.2.8.x64.appx"
$uixaml_x64_url = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/$uixaml_x64_filename"

### Check if dependencies files already cached in script folder.
$vclibs_x64_file_cached = Get-ChildItem -Path $PSScriptRoot | Where-Object -FilterScript { $_.Name -eq $vclibs_x64_filename }
$uixaml_x64_file_cached = Get-ChildItem -Path $PSScriptRoot | Where-Object -FilterScript { $_.Name -eq $uixaml_x64_filename }
# Defining pattern for search Windows Terminal msixbundle file in script directory.
$Pattern = if ($Preview) { "Microsoft.WindowsTerminalPreview_*.msixbundle" } else { "Microsoft.WindowsTerminal_*.msixbundle" }
$WindowsTerminal_file_cached = Get-ChildItem -Path $PSScriptRoot | `
    Where-Object -FilterScript { $_.Name -like $Pattern } | `
    Sort-Object -Property LastWriteTime | `
    Select-Object -Last 1
if ($WindowsTerminal_file_cached) {
    $WindowsTerminal_cached_filename = $WindowsTerminal_file_cached.Name
}

### Determining Destination Root path. Script directory for DownloadOnly. Temp directory if other cases.
$DestinationRoot = if ($DownloadOnly) { $PSScriptRoot } else { $env:temp }

if (-not $OfflineInstall) {
    ### Getting latest download links from microsoft/terminal repository
    # Getting releases
    $Releases = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/terminal/releases" -Headers @{"Accept" = "application/json" }
    # Getting LatestTag of WindowsTerminal or WindowsTerminal Preview
    $WindowsTerminalLatestTag = $Releases | Where-Object -FilterScript { $_.prerelease -eq $Preview } | Select-Object -First 1
    $WindowsTerminalDownloadLink = $WindowsTerminalLatestTag.assets | `
        Where-Object -FilterScript { $_.name -like "*.msixbundle" } | `
        Select-Object -ExpandProperty browser_download_url
    # Getting msixbundle filename
    $WindowsTerminalFileName = Split-Path -Path $WindowsTerminalDownloadLink -Leaf

    # Downloading Microsoft.VCLibs.x64.14.00.Desktop.appx or using cache
    if (-not $vclibs_x64_file_cached) {
        $vclibs_x64_FilePath = Join-Path -Path $DestinationRoot -ChildPath $vclibs_x64_filename
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $vclibs_x64_url -OutFile $vclibs_x64_FilePath | Out-Null
        }
        catch {
            Throw "Unable to download file from $vclibs_x64_url"
            exit
        }
    }
    else {
        $vclibs_x64_FilePath = $vclibs_x64_file_cached.FullName
    }
    # Downloading Microsoft.UI.Xaml.2.8.x64.appx or using cache
    if (-not $uixaml_x64_file_cached) {
        $uixaml_x64_FilePath = Join-Path -Path $DestinationRoot -ChildPath $uixaml_x64_filename
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $uixaml_x64_url -OutFile $uixaml_x64_FilePath | Out-Null
        }
        catch {
            Throw "Unable to download file from $uixaml_x64_url"
            exit
        }
    }
    else {
        $uixaml_x64_FilePath = $uixaml_x64_file_cached.FullName
    }

    # Download Windows Terminal using Latest Tag or using cached files
    if ($WindowsTerminalFileName -ne $WindowsTerminal_cached_filename) {
        $WindowsTerminalFilePath = Join-Path -Path $DestinationRoot -ChildPath $WindowsTerminalFileName
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $WindowsTerminalDownloadLink -OutFile $WindowsTerminalFilePath | Out-Null
        }
        catch {
            Throw "Unable to download file from $WindowsTerminalDownloadLink"
            exit
        }
    }
    else {
        $WindowsTerminalFilePath = Join-Path -Path $PSScriptRoot -ChildPath $WindowsTerminalFileName
    }
}
else {
    $vclibs_x64_FilePath = Join-Path -Path $PSScriptRoot -ChildPath $vclibs_x64_filename
    $uixaml_x64_FilePath = Join-Path -Path $PSScriptRoot -ChildPath $uixaml_x64_filename
    $WindowsTerminalFileName = $WindowsTerminal_cached_filename
    $WindowsTerminalFilePath = $WindowsTerminal_file_cached.FullName
}

### Exiting if in DownloadOnly mode.
if ($DownloadOnly) { 
    Write-Host "Files needed for $Script:PackageName OfflineInstallation downloaded to $PSScriptRoot"
    exit 
}

### Checking dependencies files
$vclibs_x64_file_present = Test-Path $vclibs_x64_FilePath
$uixaml_x64_file_present = Test-Path $uixaml_x64_FilePath
$WindowsTerminal_file_present = Test-Path $WindowsTerminalFilePath

### Exiting if dependencies files not present in $SourceRoot. Installation cannot proceed without files downloaded or cached beforehand.
if (-not ($vclibs_x64_file_present -and $uixaml_x64_file_present -and $WindowsTerminal_file_present)) {
    if ($OfflineInstall) {
        Throw "Dependencies files not found. Installation aborted.`nRun with -DownloadOnly switch to cache files before using -OfflineInstall."
        exit
    }
    else {
        Throw "Dependencies files not found."
    }
}

### Installing packages depending on conditions
# Install for CurrentUser
if ($Scope -eq "CurrentUser") {
    $ProgressPreference = 'SilentlyContinue'
    Add-AppxPackage -Path $vclibs_x64_FilePath | Out-Null
    Add-AppxPackage -Path $uixaml_x64_FilePath | Out-Null
    Add-AppxPackage -Path $WindowsTerminalFilePath | Out-Null
}
# Install for AllUsers
else {
    $ProgressPreference = 'SilentlyContinue'
    Add-ProvisionedAppPackage -Online -PackagePath $vclibs_x64_FilePath -SkipLicense | Out-Null
    Add-ProvisionedAppPackage -Online -PackagePath $uixaml_x64_FilePath -SkipLicense | Out-Null
    Add-ProvisionedAppPackage -Online -PackagePath $WindowsTerminalFilePath -SkipLicense | Out-Null
}

### Removing temp files
if (-not $OfflineInstall) {
    Remove-Item -Path "$env:temp\$vclibs_x64_filename" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:temp\$uixaml_x64_filename" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:temp\$WindowsTerminalFileName" -Force -ErrorAction SilentlyContinue
}

### Getting application name from repository tag or from cached file.
if (-not $OfflineInstall) {
    # Application name aquaired from repository
    #   - format refference: 'Windows Terminal Preview v1.23.11752.0'
    $Application = $WindowsTerminalLatestTag.name
}
else {
    $Application = "Windows Terminal"
    if ($Preview) { $Application += " Preview" }
    # $WindowsTerminalFileName
    #   - format refference: Microsoft.WindowsTerminal_1.22.11751.0_8wekyb3d8bbwe.msixbundle
    $WindowsTerminalFileName -match [regex]'_([\d\.]+)_' 
    $WindowsTerminalFileVersion = $Matches[1]
    if ($WindowsTerminalFileVersion) { $Application += $WindowsTerminalFileVersion }
}

Write-Host "$Application installed successfully for $Scope scope."