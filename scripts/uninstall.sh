#!/usr/bin/env bash
# scripts/uninstall.sh — cabut tema & kembalikan konfigurasi dari backup.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config
km_pick_tools
km_require_nonroot

log_step "Pencabutan Tema (Uninstall)"

KM_STATE_DIR="${KM_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/kubuntu-macos}"

if ! confirm "Hapus tema WhiteSur & kembalikan pengaturan?"; then
  log_warn "Dibatalkan."; exit 0
fi

# 1) Hapus path yang tercatat di manifest instalasi
if [ -f "$KM_STATE_DIR/installed-paths.txt" ]; then
  log_info "Menghapus komponen terpasang ..."
  sort -u "$KM_STATE_DIR/installed-paths.txt" | while IFS= read -r p; do
    [ -e "$p" ] || continue
    if [ "$KM_DRY_RUN" = "1" ]; then log_info "[dry-run] rm -rf $p"; else rm -rf "$p"; fi
  done
else
  log_warn "Manifest tidak ditemukan; hapus manual dari ~/.local/share & ~/.config/Kvantum."
fi

# 2) Hapus direktori tema yang diketahui (double-safety)
for p in \
  "$HOME/.local/share/icons/WhiteSur" \
  "$HOME/.local/share/icons/WhiteSur-dark" \
  "$HOME/.local/share/icons/WhiteSur-cursors" \
  "$HOME/.local/share/aurorae/themes/WhiteSur" \
  "$HOME/.local/share/aurorae/themes/WhiteSur-dark" \
  "$HOME/.local/share/plasma/desktoptheme/WhiteSur" \
  "$HOME/.local/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur" \
  "$HOME/.local/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur-dark" \
  "$HOME/.local/share/color-schemes/WhiteSur.colors" \
  "$HOME/.local/share/color-schemes/WhiteSurDark.colors" \
  "$HOME/.local/share/wallpapers/WhiteSur-light" \
  "$HOME/.local/share/wallpapers/WhiteSur-dark" \
  "$HOME/.config/Kvantum/WhiteSur" ; do
  [ -e "$p" ] || continue
  if [ "$KM_DRY_RUN" = "1" ]; then log_info "[dry-run] rm -rf $p"; else rm -rf "$p"; fi
done

# 3) Kembalikan konfigurasi KDE dari backup bila ada
KM_BACKUP_DIR="${KM_BACKUP_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/kubuntu-macos/backup}"
restore_cfg() { # <nama-file>
  local f="$1" latest="$KM_BACKUP_DIR/latest-$1"
  if [ -f "$latest" ]; then
    if [ "$KM_DRY_RUN" = "1" ]; then
      log_info "[dry-run] restore ~/.config/$f"
    else
      cp -aL "$latest" "$HOME/.config/$f"
      log_ok "Pulihkan ~/.config/$f"
    fi
  else
    log_info "Tidak ada backup untuk $f; kembalikan default (Breeze)."
    km_kwrite "$f" org.kde.kdecoration2 library org.kde.breeze 2>/dev/null || true
  fi
}
for f in kdeglobals kwinrc kcminputrc plasmarc; do restore_cfg "$f"; done

km_rebuild_sycoca
km_reconfigure_kwin

echo
log_ok "Uninstall selesai. Logout/login untuk menerapkan penuh."
