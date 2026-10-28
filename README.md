# Kubuntu → macOS (WhiteSur)

Satu perintah untuk mengubah Kubuntu (KDE Plasma) agar menyerupai macOS:
font, cursor, **semua ikon**, panel atas (menu bar) + dock bawah, dekorasi
jendela dengan **tombol minimize/maximize di KANAN**, gaya Qt Kvantum, dan
wallpaper — semua dari tema **WhiteSur** yang di- pin dari GitHub.

## Cara pakai (satu file)

```bash
cd Kubuntu-macOS
chmod +x install-all.sh
./install-all.sh --yes          # varian terang (default)
./install-all.sh --yes --dark   # varian gelap
```

Cukup itu. Installer akan: cek sistem → pasang paket yang kurang → ambil sumber
→ rakit komponen → terapkan tema → siapkan dock → verifikasi.

### Pratinjau tanpa mengubah apa pun

```bash
./install-all.sh --dry-run      # tampilkan rencana, tidak eksekusi
```

### Pilihan lain

| Opsi | Fungsi |
|------|--------|
| `--yes`, `-y` | Setuju semua prompt (otomatis penuh) |
| `--dark` / `--light` | Pilih varian gelap / terang |
| `--no-deps` | Lewati `apt install` |
| `--no-layout` | Lewati pengaturan panel/dock |
| `--only <tahap>` | Jalankan satu tahap: `check\|deps\|fetch\|build\|apply\|dock\|verify` |
| `--left` | Posisi tombol jendela di kiri (default: kanan) |
| `--uninstall`, `-u` | Cabut tema & kembalikan pengaturan lama |
| `--dry-run`, `-n` | Hanya tampilkan rencana |

## Yang diterapkan

- **Font**: Inter (pengganti SF Pro, lisensi OFL — boleh dibundel).
- **Ikon**: WhiteSur (dasar + varian gelap), termasuk ikon aplikasi di dock.
- **Cursor**: WhiteSur-cursors.
- **Global theme / warna / panel**: WhiteSur (menu bar atas + dock bawah ala macOS).
- **Dekorasi jendela**: Aurorae WhiteSur, tombol di **kanan** (minimize, maximize, close).
- **Gaya Qt**: Kvantum (WhiteSur / WhiteSurDark).
- **Wallpaper**: WhiteSur light/dark.

> Setelah selesai, **logout lalu login** agar font & ikon tampil sempurna.

## Sumber & keamanan

Sumber tema di- pin ke commit tetap di `config/repos.conf` (lihat tanggal pin).
Installer **tidak pernah mengeksekusi** skrip instalasi upstream — semua aset
disalin, dirakit sendiri, dan hanya ditulis ke `~/.local/share` + `~/.config`
(tanpa sudo, kecuali pemasangan paket apt).

## Struktur

```
install-all.sh          # entry point (jalankan ini)
config/
  defaults.conf         # nama tema, font, tombol, dst
  repos.conf            # sumber GitHub yang di- pin
  dependencies.conf     # info paket apt
scripts/
  check-system.sh       # validasi OS/Plasma/disk
  install-deps.sh       # apt install yang kurang (butuh sudo)
  fetch-sources.sh      # clone sumber ter- pin
  build-components.sh   # rakit komponen tema
  apply-theme.sh        # terapkan font/ikon/cursor/tombol/Kvantum
  setup-dock.sh         # panel atas + dock bawah
  verify.sh             # verifikasi hasil
  uninstall.sh          # cabut tema
  lib/                  # utilitas bersama
tests/run-tests.sh      # uji cepat tanpa menyentuh sistem
```

## Menyesuaikan

- **Isi dock**: edit `KM_DOCK_LAUNCHERS` di `config/defaults.conf`, atau drag
  ikon di dock setelah terpasang.
- **Tombol jendela di kiri**: `./install-all.sh --left` (atau ubah
  `KM_BUTTON_SIDE` di `defaults.conf`).
- **Ukuran cursor**: `KM_CURSOR_SIZE` di `defaults.conf`.

## Troubleshooting

- **Ikon/font belum berubah** → logout/login.
- **Tombol tidak pindah** → jalankan `./install-all.sh --only apply`, atau buka
  System Settings → Window Management → Window Decorations.
- **Dock tidak muncul** → jalankan `./install-all.sh --only dock`, atau System
  Settings → Panel, tambah panel & letakkan "Icons-only Task Manager".
- **Gagal clone** → cek koneksi internet, jalankan lagi `./install-all.sh --only fetch`.
- **Mau bersih** → `./install-all.sh --uninstall`.
