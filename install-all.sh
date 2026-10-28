#!/usr/bin/env bash
# =============================================================================
#  install-all.sh  —  Kubuntu → macOS dalam satu perintah.
#
#  Menyiapkan Kubuntu/Ubuntu (Plasma) agar menyerupai macOS:
#    • Font Inter (pengganti SF Pro), cursor & SEMUA ikon WhiteSur
#    • Global theme / warna / panel atas (menu bar) + dock bawah ala macOS
#    • Dekorasi jendela Aurorae, tombol minimize/maximize di KANAN
#    • Gaya Qt Kvantum, wallpaper WhiteSur
#
#  Pemakaian:
#    ./install-all.sh                 # mode interaktif (tanya dulu)
#    ./install-all.sh --yes           # langsung jalan tanpa tanya
#    ./install-all.sh --dark          # pakai varian gelap
#    ./install-all.sh --dry-run       # tampilkan rencana, tidak eksekusi
#    ./install-all.sh --help
#
#  Sumber tema di- pin dari GitHub (lihat config/repos.conf). Tidak ada installer
#  upstream yang dieksekusi — semuanya disalin & dirakit sendiri, lalu diterapkan.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/common.sh"
source "$ROOT/scripts/lib/plasma.sh"
km_load_config

usage() {
  cat <<EOF
${C_BOLD}Kubuntu-macOS $KM_VERSION${C_RESET} — peniru tampilan macOS untuk Kubuntu.

Pilihan:
  -y, --yes         Setuju semua prompt (otomatis penuh)
  -n, --dry-run     Hanya tampilkan rencana, tidak mengubah apa pun
      --dark        Pakai varian gelap (default: light / terang)
      --light       Pakai varian terang
      --no-deps     Lewati pemasangan paket (apt)
      --no-layout   Lewati pengaturan panel/dock
      --only STAGE  Jalankan satu tahap saja:
                    check | deps | fetch | build | apply | dock | verify
  -u, --uninstall   Cabut tema & kembalikan pengaturan lama
  -h, --help        Tampilkan bantuan ini

Contoh:
  ./install-all.sh --yes
  ./install-all.sh --yes --dark
  ./install-all.sh --only build
EOF
}

STAGE="all"
DO_DEPS=1
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes)      KM_YES=1 ;;
    -n|--dry-run)  KM_DRY_RUN=1 ;;
    --dark)        KM_VARIANT=dark ;;
    --light)       KM_VARIANT=light ;;
    --no-deps)     DO_DEPS=0 ;;
    --no-layout)   KM_NO_LAYOUT=1 ;;
    --only)        STAGE="${2:-}"; shift ;;
    --right|--buttons-right) KM_BUTTON_SIDE=right ;;
    --left|--buttons-left)   KM_BUTTON_SIDE=left ;;
    -u|--uninstall) UNINSTALL=1 ;;
    -h|--help)     usage; exit 0 ;;
    *) die "Opsi tak dikenal: $1 (lihat --help)" ;;
  esac
  shift
done
export KM_YES KM_DRY_RUN KM_VARIANT KM_NO_LAYOUT KM_BUTTON_SIDE

run_stage() { # <nama> <script>
  local name="$1" script="$2"
  if ! bash "$ROOT/scripts/$script"; then
    die "Tahap '$name' gagal. Perbaiki pesan error di atas lalu jalankan lagi."
  fi
}

banner() {
  cat <<EOF
${C_BOLD}${C_CYAN}
  ┌──────────────────────────────────────────┐
  │   Kubuntu → macOS  ·  WhiteSur theme      │
  │   v$KM_VERSION  ·  varian: $KM_VARIANT
  └──────────────────────────────────────────┘
${C_RESET}
EOF
}

# Mode uninstall
if [ "$UNINSTALL" = "1" ]; then
  banner
  run_stage "uninstall" "uninstall.sh"
  exit 0
fi

banner
log_info "Mode: $([ "$KM_DRY_RUN" = "1" ] && echo 'DRY-RAN (tidak mengubah apa pun)' || echo 'eksekusi nyata')"
log_info "Root proyek: $KM_ROOT"
km_pick_tools
log_info "Plasma terdeteksi: versi $KM_PLASMA_MAJOR"

# Tahap 'check' berjalan kecuali --only tahap lain selain check
if [ "$STAGE" = "all" ] || [ "$STAGE" = "check" ]; then
  run_stage "check" "check-system.sh"
  [ "$STAGE" = "check" ] && exit 0
fi

# konfirmasi sekali sebelum mulai
if [ "$KM_DRY_RUN" != "1" ] && [ "$KM_YES" != "1" ]; then
  echo
  confirm "Siap memasang tema macOS (varian $KM_VARIANT) ke user '$USER'?" \
    || { log_warn "Dibatalkan pengguna."; exit 1; }
fi

case "$STAGE" in
  all)
    if [ "$DO_DEPS" = "1" ]; then run_stage "deps"  "install-deps.sh"; fi
    run_stage "fetch" "fetch-sources.sh"
    run_stage "build" "build-components.sh"
    run_stage "apply" "apply-theme.sh"
    run_stage "dock"  "setup-dock.sh"
    run_stage "verify" "verify.sh"
    ;;
  deps)   run_stage "deps"   "install-deps.sh" ;;
  fetch)  run_stage "fetch"  "fetch-sources.sh" ;;
  build)  run_stage "build"  "build-components.sh" ;;
  apply)  run_stage "apply"  "apply-theme.sh" ;;
  dock)   run_stage "dock"   "setup-dock.sh" ;;
  verify) run_stage "verify" "verify.sh" ;;
  *) die "Tahap tak dikenal: $STAGE" ;;
esac

echo
printf '%s\n' "${C_BOLD}${C_GREEN}✓ Selesai!${C_RESET}"
cat <<EOF

Yang sudah diterapkan:
  • Font Inter, cursor WhiteSur-cursors, ikon WhiteSur (semua ikon + dock)
  • Global theme WhiteSur$([ "$KM_VARIANT" = "dark" ] && echo ' (gelap)')
  • Panel atas (menu bar) + dock bawah ala macOS
  • Tombol jendela di KANAN (minimize, maximize, close)
  • Gaya Qt Kvantum + wallpaper WhiteSur

Tips:
  • Logout lalu login agar font & ikon tampil sempurna.
  • Ganti varian:  ./install-all.sh --dark   atau   --light
  • Cabut tema:     ./install-all.sh --uninstall
  • Ubah isi dock:  System Settings → Panel → dock → drag ikon
EOF
