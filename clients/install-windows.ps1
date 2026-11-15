# Installs RustDesk on Windows and points it at YOUR server.
# Run in PowerShell AS ADMINISTRATOR:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\install-windows.ps1 -Config '<CONFIG_STRING>' [-Password '<PASSWORD>']
param(
    [Parameter(Mandatory = $true)][string]$Config,
    [string]$Password = "",
    [string]$Version = ""
)
$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Uruchom PowerShell jako Administrator." }

if (-not $Password) {
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $Password = -join (1..16 | ForEach-Object { $chars | Get-Random })
}

if (-not $Version) {
    # Follow the /latest redirect to get the tag (no API rate limit).
    $req = [Net.WebRequest]::Create("https://github.com/rustdesk/rustdesk/releases/latest")
    $req.AllowAutoRedirect = $true
    $resp = $req.GetResponse()
    $Version = ($resp.ResponseUri.AbsolutePath -split '/')[-1]
    $resp.Close()
}
$Version = $Version.TrimStart('v')
Write-Host ">> RustDesk $Version"

$tmp = Join-Path $env:TEMP "rustdesk-$Version.exe"
Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/rustdesk/rustdesk/releases/download/$Version/rustdesk-$Version-x86_64.exe" -OutFile $tmp

Write-Host ">> Instalacja..."
Start-Process -FilePath $tmp -ArgumentList "--silent-install" -Wait
$exe = Join-Path $env:ProgramFiles "RustDesk\rustdesk.exe"
for ($i = 0; $i -lt 60 -and -not (Test-Path $exe); $i++) { Start-Sleep 1 }
if (-not (Test-Path $exe)) { throw "Instalacja nie powiodla sie ($exe nie istnieje)." }

# Make sure the service exists and runs
if (-not (Get-Service -Name RustDesk -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $exe -ArgumentList "--install-service" -Wait
    Start-Sleep 10
}
Start-Service RustDesk -ErrorAction SilentlyContinue
Start-Sleep 5

Set-Location (Split-Path $exe)
.\rustdesk.exe --config $Config | Out-Null
.\rustdesk.exe --option verification-method use-permanent-password | Out-Null
.\rustdesk.exe --option approve-mode password | Out-Null
.\rustdesk.exe --password $Password | Out-Null
Restart-Service RustDesk -ErrorAction SilentlyContinue
Start-Sleep 5
$id = (.\rustdesk.exe --get-id | Out-String).Trim()
Remove-Item $tmp -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "======================================"
Write-Host " Host    : $env:COMPUTERNAME"
Write-Host " ID      : $id"
Write-Host " Password: $Password"
Write-Host "======================================"
Write-Host "Wpisz to do computers.csv (i trzymaj haslo w menedzerze hasel)."
