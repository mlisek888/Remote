# Fox Zdalny - instalacja od zera na Windows (usluga + stale haslo + autostart).
#
# Najprosciej: polozyc ten skrypt obok instalatora FoxZdalny-*.exe (albo w Pobranych),
# kliknac prawym -> "Uruchom za pomoca programu PowerShell". Skrypt sam poprosi o
# uprawnienia administratora i o haslo.
#
# Z linii polecen:
#   powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
#   powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -Password 'haslo' -NoSleep
#   powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -Installer 'https://.../FoxZdalny.exe'
#
# Parametry:
#   -Installer  sciezka lub adres https do FoxZdalny-*.exe (domyslnie: szuka obok skryptu i w Pobranych)
#   -Password   stale haslo (domyslnie: zapyta; puste = wygeneruje losowe)
#   -NoSleep    wylacza usypianie/hibernacje (fotobudki, komputery stale dostepne)
param(
    [string]$Installer = "",
    [string]$Password = "",
    [switch]$NoSleep
)
$ErrorActionPreference = "Stop"
$App = "FoxZdalny"

# --- 1. Administrator (jesli nie, uruchom ponownie z podniesionymi uprawnieniami) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-NoExit", "-File", "`"$PSCommandPath`"")
    if ($Installer) { $argList += @("-Installer", "`"$Installer`"") }
    if ($Password)  { $argList += @("-Password", "`"$Password`"") }
    if ($NoSleep)   { $argList += "-NoSleep" }
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit
}

function Step($msg) { Write-Host ">> $msg" -ForegroundColor Cyan }
$dir = Join-Path $env:ProgramFiles $App
$exe = Join-Path $dir "$App.exe"

# --- 2. Haslo ---
if (-not $Password) {
    $sec = Read-Host "Podaj stale haslo dla tego komputera (Enter = wygeneruj losowe)" -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
}
$generated = $false
if (-not $Password) {
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
    $Password = -join (1..16 | ForEach-Object { $chars | Get-Random })
    $generated = $true
}

# --- 3. Instalacja (pomijana, jesli usluga juz jest) ---
if (Get-Service $App -ErrorAction SilentlyContinue) {
    Step "Fox Zdalny jest juz zainstalowany - tylko konfiguracja."
} else {
    if (-not $Installer) {
        $search = @($PSScriptRoot, (Join-Path $env:USERPROFILE "Downloads"), (Join-Path $env:PUBLIC "Downloads"))
        $found = $search | Where-Object { $_ -and (Test-Path $_) } |
            ForEach-Object { Get-ChildItem $_ -Filter "FoxZdalny-*.exe" -File -ErrorAction SilentlyContinue } |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $found) { throw "Nie znalazlem FoxZdalny-*.exe obok skryptu ani w Pobranych. Podaj -Installer." }
        $Installer = $found.FullName
    }
    if ($Installer -match '^https?://') {
        Step "Pobieram instalator..."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $tmp = Join-Path $env:TEMP "FoxZdalny-setup.exe"
        Invoke-WebRequest -UseBasicParsing -Uri $Installer -OutFile $tmp
        $Installer = $tmp
    }
    if (-not (Test-Path $Installer)) { throw "Nie ma pliku $Installer" }
    Unblock-File $Installer -ErrorAction SilentlyContinue
    Step "Instaluje z $Installer (do 2 minut)..."
    Start-Process -FilePath $Installer -ArgumentList "--silent-install" -Wait
    for ($i = 0; $i -lt 120; $i++) {
        if ((Test-Path $exe) -or (Test-Path (Join-Path $dir "rustdesk.exe"))) { break }
        Start-Sleep 1
    }
    Start-Sleep 5
}

# Starsze buildy mialy w paczce rustdesk.exe zamiast FoxZdalny.exe - wtedy usluga sie nie rejestruje.
$legacy = Join-Path $dir "rustdesk.exe"
if (-not (Test-Path $exe) -and (Test-Path $legacy)) {
    Step "Poprawiam nazwe pliku (starszy build)..."
    Rename-Item $legacy "$App.exe"
}
if (-not (Test-Path $exe)) { throw "Instalacja nie powiodla sie: brak $exe" }
if (-not (Get-Service $App -ErrorAction SilentlyContinue)) {
    Step "Rejestruje usluge..."
    & $exe --after-install | Out-Null
    for ($i = 0; $i -lt 30 -and -not (Get-Service $App -ErrorAction SilentlyContinue); $i++) { Start-Sleep 1 }
}
if (-not (Get-Service $App -ErrorAction SilentlyContinue)) { throw "Usluga $App nie powstala." }

# --- 4. Autostart uslugi ---
Step "Usluga: start automatyczny..."
Set-Service $App -StartupType Automatic
Start-Service $App -ErrorAction SilentlyContinue
Start-Sleep 8

# --- 5. Ikona w zasobniku po zalogowaniu ---
$startup = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\Startup\$App Tray.lnk"
if (-not (Test-Path $startup)) {
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($startup)
    $s.TargetPath = $exe
    $s.Arguments = "--tray"
    $s.Save()
}

# --- 6. Haslo ---
Step "Ustawiam stale haslo..."
Push-Location $dir
& $exe --password $Password | Out-Null
Start-Sleep 3
$id = (& $exe --get-id | Out-String).Trim()
Pop-Location

# --- 7. Bez usypiania (opcjonalnie) ---
if ($NoSleep) {
    Step "Wylaczam usypianie i hibernacje..."
    powercfg /change standby-timeout-ac 0 | Out-Null
    powercfg /change standby-timeout-dc 0 | Out-Null
    powercfg /change hibernate-timeout-ac 0 | Out-Null
    powercfg /hibernate off | Out-Null
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Komputer : $env:COMPUTERNAME"
Write-Host " ID       : $id"
if ($generated) { Write-Host " Haslo    : $Password   (wygenerowane - zapisz w Vaultwardenie!)" }
else            { Write-Host " Haslo    : (to, ktore podales)" }
Write-Host " Usluga   : $((Get-Service $App).Status), start: $((Get-Service $App).StartType)"
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Na Macu: wpisz ID -> Polacz -> haslo, zaznacz 'Zapamietaj haslo', potem Ulubione."
