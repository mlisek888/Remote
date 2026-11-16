# Fox Zdalny – własna aplikacja

Fox Zdalny to RustDesk 1.5.3 z Twoją nazwą, ikoną i **wbudowanym Twoim serwerem**.
Po instalacji niczego nie trzeba konfigurować: serwer i klucz są w programie na stałe,
a ustawień sieci nie da się zmienić z poziomu aplikacji.

Budowanie odbywa się na GitHub Actions (repo jest publiczne, więc minuty są darmowe).

## Co jest wbudowane

| Ustawienie | Wartość |
|---|---|
| Nazwa | FoxZdalny (Windows, macOS). Na Linuxie polecenie i usługa nadal nazywają się `rustdesk` |
| Serwer ID / relay | sekret `FOX_HOST` |
| Klucz serwera | sekret `FOX_KEY` |
| Dostęp przychodzący | tylko stałe hasło, bez klikania „Akceptuj” |
| Sprawdzanie aktualizacji | wyłączone (żeby nie podsuwało zwykłego RustDeska) |

Zmiany robisz w `client/branding.json`.

## 1. Jednorazowo: sekrety w GitHubie

Repo → **Settings → Secrets and variables → Actions → New repository secret**:

- `FOX_HOST` = `zdalny.foxfotograf.pl` (adres Twojego serwera)
- `FOX_KEY` = zawartość `id_ed25519.pub` z serwera (`server/print-config.sh` wypisuje ją jako „Key”)

Bez nich build od razu się zatrzyma z czytelnym błędem.

## 2. Budowanie

Repo → **Actions → Build Fox Zdalny → Run workflow**.
Build uruchamia się też sam przy każdej zmianie w `client/`.

Trwa ok. 1–1,5 h. Na końcu powstaje **szkic wydania** (Releases → Draft). Szkic widzisz tylko Ty,
a nie publicznie. W nim są pliki:

| Plik | Dla kogo |
|---|---|
| `FoxZdalny-1.5.3-x86_64.exe` | Windows |
| `FoxZdalny-1.5.3-aarch64.dmg` | Mac z Apple M1/M2/M3/M4 |
| `FoxZdalny-1.5.3-x86_64.dmg` | Mac z Intelem |
| `FoxZdalny-1.5.3-x86_64.deb` | Ubuntu / Debian / Mint |
| `FoxZdalny-1.5.3-x86_64.rpm` | Fedora / RHEL |

## 3. Instalacja na komputerach

Skrypty w `clients/fox/` instalują aplikację jako usługę, ustawiają losowe hasło
(albo Twoje) i wypisują **ID + hasło** do zapisania w Vaultwardenie:

```powershell
# Windows, PowerShell jako Administrator
Set-ExecutionPolicy -Scope Process Bypass -Force
.\install-windows.ps1 -Installer .\FoxZdalny-1.5.3-x86_64.exe
```
```bash
sudo ./install-macos.sh FoxZdalny-1.5.3-aarch64.dmg      # macOS
sudo ./install-linux.sh FoxZdalny-1.5.3-x86_64.deb        # Linux
```

Na komputerze, **z którego** się łączysz, wystarczy zainstalować tego samego Fox Zdalny
(bez skryptu): wpisujesz ID, potem hasło i gotowe.

### macOS bez podpisu Apple

- Skrypt zdejmuje kwarantannę, więc aplikacja się uruchomi. Jeśli instalujesz ręcznie
  z dmg: prawy klik na aplikacji → **Otwórz** → **Otwórz** (tylko za pierwszym razem).
- *Nagrywanie ekranu* i *Dostępność* trzeba włączyć ręcznie w ustawieniach.
- Po instalacji **nowej wersji** macOS może poprosić o te uprawnienia jeszcze raz
  (bez podpisu Apple nie rozpoznaje, że to ta sama aplikacja). Wtedy w ustawieniach
  usuń FoxZdalny z listy (−) i dodaj ponownie.

### Windows bez podpisu

Przy pierwszym uruchomieniu SmartScreen pokaże „System Windows ochronił ten komputer”.
Kliknij **Więcej informacji → Uruchom mimo to**. Skrypt instalacyjny tego nie wymaga.

## Aktualizacja do nowej wersji RustDesk

```bash
git clone --depth 1 -b 1.5.4 --recurse-submodules https://github.com/rustdesk/rustdesk /tmp/rd
python3 client/gen_workflow.py /tmp/rd 1.5.4
git commit -am "Fox Zdalny 1.5.4" && git push
```

`apply_branding.py` sprawdza dokładnie fragmenty kodu, które zmienia. Jeśli RustDesk je przebuduje,
build zatrzyma się z komunikatem zamiast po cichu wyprodukować zwykłego RustDeska.

## Własna ikona

Podmień `client/branding/icon-1024.png` (kwadrat 1024×1024, przezroczyste rogi) i uruchom:

```bash
python3 client/branding/make_icons.py --from-png
```

## Pliki

```
client/
  branding.json          nazwa, bundle id, wymuszone ustawienia
  apply_branding.py      nakłada branding na źródła RustDesk (uruchamiany w CI)
  macos_rebrand.sh       zmienia RustDesk.app → FoxZdalny.app i podpisuje ad-hoc
  gen_workflow.py        generuje .github/workflows/build-fox-zdalny.yml z CI RustDeska
  branding/              ikona, logo, generator ikon, gotowe pliki (overlay/)
clients/fox/             skrypty instalacyjne dla komputerów
```

Licencja: RustDesk jest na AGPL-3.0. Do własnego użytku możesz go dowolnie zmieniać.
Gdybyś kiedyś dawał tę aplikację innym osobom, musisz udostępnić im też jej kod
(to repo plus źródła RustDesk).
