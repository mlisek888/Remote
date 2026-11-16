# Instaluje Fox Zdalny na Windows jako usluge i ustawia stale haslo.
# PowerShell jako Administrator:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\install-windows.ps1 -Installer .\FoxZdalny-1.5.3-x86_64.exe [-Password 'haslo']
param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [string]$Password = ""
)
$ErrorActionPreference = "Stop"
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Uruchom PowerShell jako Administrator." }
if (-not (Test-Path $Installer)) { throw "Nie ma pliku $Installer" }
if (-not $Password) {
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $Password = -join (1..16 | ForEach-Object { $chars | Get-Random })
}

Write-Host ">> Instalacja Fox Zdalny..."
Start-Process -FilePath (Resolve-Path $Installer) -ArgumentList "--silent-install" -Wait
$exe = Join-Path $env:ProgramFiles "FoxZdalny\FoxZdalny.exe"
for ($i = 0; $i -lt 90 -and -not (Test-Path $exe); $i++) { Start-Sleep 1 }
if (-not (Test-Path $exe)) { throw "Instalacja nie powiodla sie ($exe nie istnieje)." }
Start-Sleep 10
Start-Service FoxZdalny -ErrorAction SilentlyContinue
Start-Sleep 5

Set-Location (Split-Path $exe)
.\FoxZdalny.exe --password $Password | Out-Null
Start-Sleep 3
$id = (.\FoxZdalny.exe --get-id | Out-String).Trim()

Write-Host ""
Write-Host "======================================"
Write-Host " Komputer: $env:COMPUTERNAME"
Write-Host " ID      : $id"
Write-Host " Haslo   : $Password"
Write-Host "======================================"
Write-Host "Zapisz w Vaultwardenie."
