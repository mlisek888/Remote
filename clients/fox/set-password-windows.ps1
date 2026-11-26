# Fox Zdalny - zmiana stalego hasla na juz zainstalowanym komputerze.
#   powershell -ExecutionPolicy Bypass -File .\set-password-windows.ps1
#   powershell -ExecutionPolicy Bypass -File .\set-password-windows.ps1 -Password 'noweHaslo'
param([string]$Password = "")
$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$PSCommandPath`"")
    if ($Password) { $argList += @("-Password", "`"$Password`"") }
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit
}

$exe = Join-Path $env:ProgramFiles "FoxZdalny\FoxZdalny.exe"
if (-not (Test-Path $exe)) { throw "Nie ma $exe - najpierw zainstaluj Fox Zdalny (install-windows.ps1)." }
if ((Get-Service FoxZdalny -ErrorAction SilentlyContinue).Status -ne 'Running') {
    Start-Service FoxZdalny
    Start-Sleep 8
}

if (-not $Password) {
    $a = Read-Host "Nowe stale haslo" -AsSecureString
    $b = Read-Host "Powtorz haslo" -AsSecureString
    $p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a))
    $p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($b))
    if (-not $p1) { throw "Haslo nie moze byc puste." }
    if ($p1 -cne $p2) { throw "Hasla sie roznia." }
    $Password = $p1
}

Push-Location (Split-Path $exe)
$out = (& $exe --password $Password | Out-String).Trim()
$id = (& $exe --get-id | Out-String).Trim()
Pop-Location
Write-Host ""
Write-Host "Haslo zmienione ($out) dla ID $id na $env:COMPUTERNAME." -ForegroundColor Green
Write-Host "Na Macu przy nastepnym polaczeniu wpisz nowe haslo i zaznacz 'Zapamietaj haslo'."
