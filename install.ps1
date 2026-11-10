# Installs a CLI from its latest GitHub release, on Windows:
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/dittofleet/.github/main/install.ps1))) <owner>/<repo> [<binary>]
#
# This is install.sh for Windows, and takes the same arguments. A bare
# <repo> is a dittofleet CLI. <binary> names the release asset
# (<binary>-windows-x64.exe) and the installed command, and defaults to
# <repo>. A release that also has <binary>w-windows-x64.exe gets that
# installed beside it.
#
# It goes in ~\.local\bin, or <BINARY>_INSTALL_DIR (navi: NAVI_INSTALL_DIR,
# port-pool: PORT_POOL_INSTALL_DIR), which is added to your PATH. Then the
# CLI's own `postinstall` command does its first-time setup.
#
# It runs in Windows PowerShell 5.1 as well as PowerShell 7. It never calls
# exit, which would close the terminal it was pasted into.
param([string]$Repo, [string]$Binary)

$ErrorActionPreference = 'Stop'
# Windows PowerShell draws a progress bar that makes a download many times
# slower.
$ProgressPreference = 'SilentlyContinue'

$owner = 'dittofleet'
if ($Repo -match '/') { $owner, $Repo = $Repo -split '/', 2 }
if (-not $Binary) { $Binary = $Repo }
if ($owner -notmatch '^[A-Za-z0-9-]+$' -or $Repo -notmatch '^[A-Za-z0-9._-]+$' -or $Binary -cnotmatch '^[a-z0-9-]+$') {
    throw 'usage: install.ps1 <owner>/<repo> [<binary>], e.g. dittofleet/navi'
}

$dest = [Environment]::GetEnvironmentVariable(($Binary.ToUpperInvariant() -replace '-', '_') + '_INSTALL_DIR')
if (-not $dest) { $dest = Join-Path $HOME '.local\bin' }
$target = Join-Path $dest "$Binary.exe"
# The one build serves every machine: Windows on ARM runs x64 programs.
$releases = "https://github.com/$owner/$Repo/releases/latest/download"

New-Item -ItemType Directory -Force $dest | Out-Null
# Staged next to the binary, so an interruption cannot leave a truncated
# one. Both are downloaded before either is put in place.
$tmp = Join-Path $dest ".$Binary-update-$PID"
Write-Host "Downloading $releases/$Binary-windows-x64.exe..."
try {
    Invoke-WebRequest -Uri "$releases/$Binary-windows-x64.exe" -OutFile $tmp -UseBasicParsing
} catch {
    Remove-Item $tmp -ErrorAction SilentlyContinue
    throw "Could not download $Binary for Windows. Not every CLI is built for every system."
}
# A CLI that starts a daemon at login also releases <binary>w.exe, which
# runs it with no console window. Most CLIs have none, which is a 404.
try {
    Invoke-WebRequest -Uri "$releases/${Binary}w-windows-x64.exe" -OutFile "$tmp-w" -UseBasicParsing
} catch {
    Remove-Item "$tmp-w" -ErrorAction SilentlyContinue
    if ([int]$_.Exception.Response.StatusCode -ne 404) {
        Remove-Item $tmp -ErrorAction SilentlyContinue
        throw
    }
}

# Windows will not overwrite a program that is running, as the CLI's daemon
# may be, but it will rename one. So an old binary is moved aside, and
# deleted by a later install or update that finds nothing running it. The
# CLI's own `update` does the same, under the same name.
Get-ChildItem $dest -Filter ".$Binary-old-*" -Force | Remove-Item -Force -ErrorAction SilentlyContinue
foreach ($new in @(@($tmp, $target), @("$tmp-w", (Join-Path $dest "${Binary}w.exe")))) {
    if (-not (Test-Path $new[0])) { continue }
    if (Test-Path $new[1]) {
        Move-Item $new[1] (Join-Path $dest ".$Binary-old-$([guid]::NewGuid().ToString('N'))")
    }
    Move-Item $new[0] $new[1]
}
Write-Host "Installed $Binary to $target"

# Read and written unexpanded, so entries like %USERPROFILE%\bin stay as
# they are.
$environment = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
$path = [string]$environment.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
if (($path -split ';') -notcontains $dest) {
    $kind = if ($path) { $environment.GetValueKind('Path') } else { 'ExpandString' }
    $environment.SetValue('Path', ($path.TrimEnd(';') + ';' + $dest).TrimStart(';'), $kind)
    # Windows only tells running programs that the environment changed when
    # a variable is set this way, and without that new terminals would not
    # see the PATH until the next login. Clearing one that does not exist
    # is enough.
    [Environment]::SetEnvironmentVariable('DITTOFLEET_INSTALL', $null, 'User')
    $env:Path = "$env:Path;$dest"
    Write-Host "Added $dest to your PATH. Other terminals that are already open need restarting to use $Binary."
}
$environment.Close()

& $target postinstall
