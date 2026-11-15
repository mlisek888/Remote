# Remote – prywatny serwer zdalnego pulpitu (RustDesk)

Twój własny serwer do zdalnego dostępu do komputerów Windows / macOS / Linux.
Silnik: [RustDesk](https://github.com/rustdesk/rustdesk) (open source), serwer `hbbs` + `hbbr` w Dockerze.
Żadnych publicznych serwerów RustDesk – cały ruch idzie przez Twoją maszynę
(albo bezpośrednio P2P między komputerami, zaszyfrowany kluczem Twojego serwera).

```
 [Twój laptop – klient RustDesk] ──┐
                                   ├──► [Twój serwer: hbbs :21115-21116, hbbr :21117]
 [20 zdalnych komputerów – agent] ─┘        (ID, NAT traversal, relay gdy P2P się nie uda)
```

## 1. Serwer (jednorazowo)

Wymagania: Linux (VPS lub domowy serwer), publiczny IP lub domena, otwarte porty:

| Port  | Protokół | Do czego          |
|-------|----------|-------------------|
| 21115 | TCP      | test NAT          |
| 21116 | TCP+UDP  | ID / rendezvous   |
| 21117 | TCP      | relay             |

Za routerem domowym → przekieruj te porty na serwer.

```bash
git clone <to-repo> remote && cd remote/server
sudo ./setup.sh remote.twojadomena.pl      # albo publiczny IP
```

Skrypt instaluje Dockera (jeśli brak), otwiera porty w `ufw`, uruchamia serwer
i wypisuje **Config string** – jeden ciąg znaków z adresem i kluczem.
Zapisuje go też w `server/data/client-config.txt`. Wyświetlisz go ponownie: `./print-config.sh`.

**Zrób backup kluczy** (`./backup.sh`) – jak je zgubisz, trzeba przekonfigurować wszystkie komputery.

## 2. Komputery zdalne (każdy z ~20)

Każdy skrypt: pobiera najnowszy RustDesk, instaluje jako usługę, ustawia Twój serwer,
włącza dostęp **tylko stałym hasłem** (bez klikania „akceptuj” – działa bez nikogo przy komputerze),
ustawia hasło (losowe 16 znaków jeśli nie podasz) i wypisuje **ID + hasło**.

**Windows** – PowerShell jako Administrator:
```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install-windows.ps1 -Config 'TWOJ_CONFIG_STRING'
```

**Linux** (Debian/Ubuntu/Mint/Fedora/RHEL):
```bash
sudo ./install-linux.sh 'TWOJ_CONFIG_STRING'
# opcjonalnie wyłącz Waylanda w GDM (patrz niżej):
sudo ./install-linux.sh 'TWOJ_CONFIG_STRING' '' --disable-wayland
```

**macOS**:
```bash
sudo ./install-macos.sh 'TWOJ_CONFIG_STRING'
```
Potem **ręcznie raz**: Ustawienia systemowe → Prywatność i ochrona →
*Nagrywanie ekranu* i *Dostępność* → włącz RustDesk. Apple nie pozwala tego zautomatyzować.

Wypisane ID/hasło dopisz do `computers.csv` (wzór: `computers.example.csv`, plik jest w `.gitignore`).
Hasła trzymaj w menedżerze haseł – każdy komputer najlepiej z innym.

## 3. Twój komputer, z którego się łączysz

1. Zainstaluj RustDesk z <https://github.com/rustdesk/rustdesk/releases/latest>.
2. Ustawienia → Sieć → **ID/Relay server** → przycisk *Import server config* (wklej Config string)
   albo ręcznie: ID server i Relay server = Twoja domena, Key = klucz z `print-config.sh`.
3. Wpisz ID zdalnego komputera → Połącz → hasło. Zaznacz *Zapamiętaj hasło* i dodaj do **Ulubionych** –
   masz listę wszystkich 20 maszyn w aplikacji.

Na telefonie (Android/iOS) działa tak samo – ta sama apka RustDesk, ten sam import konfiguracji.

## Bezpieczeństwo

- Serwer akceptuje tylko klientów znających jego klucz publiczny; połączenia są szyfrowane end-to-end.
- Na zdalnych komputerach: tylko stałe hasło, tryb bez potwierdzania. Używaj długich, różnych haseł.
- Nie commituj `server/data/` (klucz prywatny) – jest w `.gitignore`.
- Aktualizacje serwera: `cd server && docker compose pull && docker compose up -d`.

## Znane ograniczenia

- **Linux + Wayland**: dostęp nienadzorowany (ekran logowania, brak zalogowanego użytkownika) działa
  tylko na X11. Na Ubuntu/GDM użyj `--disable-wayland` i zrestartuj komputer.
- **macOS**: uprawnienia ekranu/dostępności trzeba nadać ręcznie (raz na komputer).
- **Windows ARM / Linux ARM 32-bit**: skrypty obsługują x86_64 (Windows) i x86_64/aarch64 (Linux, macOS).
- Książka adresowa synchronizowana między urządzeniami wymaga płatnego RustDesk Server Pro –
  przy 20 komputerach wystarczą Ulubione + `computers.csv`.

## Struktura

```
server/
  docker-compose.yml   hbbs + hbbr (network_mode: host)
  setup.sh             instalacja i start serwera
  print-config.sh      wypisuje adres, klucz i Config string
  backup.sh            backup kluczy
clients/
  install-windows.ps1
  install-macos.sh
  install-linux.sh
computers.example.csv  wzór inwentarza
```
