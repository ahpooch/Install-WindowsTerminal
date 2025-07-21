# install-windows-terminal
Easily install the new Windows Terminal or Windows Terminal Preview on Windows Server 2022 and newer.

Inspired by: https://github.com/microsoft/terminal/discussions/13983#discussioncomment-7554301

## Current versions provided by scripts
The script performs calls to a GitHub API to find the latest `Windows Terminal` and `Windows Terminal Preview` versions available.

## Usage
### Online installation
```Powershell
# Example 1: Installing for current user.
& .\Install-WindowsTerminal.ps1

# Example 2: Installing for all users.
& .\Install-WindowsTerminal.ps1 -Scope AllUsers

# Example 3: Installing Preview version for current user.
& .\Install-WindowsTerminal.ps1 -Preview

# Example 4: Installing Preview version for all users.
& .\Install-WindowsTerminal.ps1 -Scope AllUsers -Preview
```
### Offline installation
Install-WindowsTerminal.ps1 can be used as offline installer.
#### Dowloading content for offline install
Using computer with internet access download offline content for desired version.
```Powershell
    # Download files for Windows Terminal offline installation.
    & .\Install-WindowsTerminal.ps1 -DownloadOnly
```
Or
```Powershell
    # Download files for Windows Terminal Preview offline installation.
    & .\Install-WindowsTerminal.ps1 -Preview -DownloadOnly
```
#### Permorm offline installation
```Powershell
    # Installation of Windows Termina for all users, using cached files in the script directory.
    & .\Install-WindowsTerminal.ps1 -Scope AllUsers -OfflineInstall
```
Or
```Powershell
    # Installation of Windows Terminal Preview for all users, using cached files in the script directory.
    & .\Install-WindowsTerminal.ps1 -Scope AllUsers -Preview -OfflineInstall
```
