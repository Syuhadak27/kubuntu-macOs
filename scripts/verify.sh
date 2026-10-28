#!/usr/bin/env bash
# scripts/verify.sh — verifikasi bahwa semua komponen & pengaturan sudah benar.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config
km_pick_tools

log_step "Verifikasi"

if [ "$KM_DRY_RUN" = "1" ]; then
  log_info "[dry-run] melewati verifikasi (tidak ada yang benar-benar dipasang)."
  exit 0
fi

if [ "$KM_VARIANT" = "dark" ]; then
  exp_color="$KM_COLOR_DARK"; exp_icon="$KM_ICON_THEME-dark"
  exp_deco="__aurorae__svg__WhiteSur-dark"; exp_plasma="$KM_THEME_DARK"
  exp_style="kvantum-dark"
else
  exp_color="$KM_COLOR_LIGHT"; exp_icon="$KM_ICON_THEME"
  exp_deco="__aurorae__svg__WhiteSur"; exp_plasma="$KM_THEME_LIGHT"
  exp_style="kvantum"
fi

pass=0; fail=0
check_dir() { # <label> <path>
  if [ -d "$2" ]; then log_ok "$1: $2"; pass=$((pass+1));
  else log_err "$1 HILANG: $2"; fail=$((fail+1)); fi
}
check_key() { # <label> <file> <group> <key> <expected>
  local got
  got="$(km_kread "$2" "$3" "$4")"
  if [ "$got" = "$5" ]; then log_ok "$1 = $got"; pass=$((pass+1));
  else log_err "$1: dapat '$got', harap '$5'"; fail=$((fail+1)); fi
}

echo "-- Berkas/aset --"
check_dir "Icon theme"        "$HOME/.local/share/icons/$exp_icon"
check_dir "Icon dasar"        "$HOME/.local/share/icons/$KM_ICON_THEME"
check_dir "Cursor theme"      "$HOME/.local/share/icons/$KM_CURSOR_THEME"
check_dir "Aurorae (deco)"    "$HOME/.local/share/aurorae/themes/WhiteSur"
check_dir "Look-and-feel"     "$HOME/.local/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur"
check_dir "Plasma theme"      "$HOME/.local/share/plasma/desktoptheme/WhiteSur"
check_dir "Color scheme"      "$HOME/.local/share/color-schemes/$KM_COLOR_LIGHT.colors"
check_dir "Kvantum theme"     "$HOME/.config/Kvantum/$KM_KVANTUM_LIGHT"

echo
echo "-- Pengaturan KDE --"
check_key "Skema warna"       kdeglobals General      ColorScheme  "$exp_color"
check_key "Tema ikon"         kdeglobals Icons        Theme        "$exp_icon"
check_key "Style widget"      kdeglobals KDE          widgetStyle  "$exp_style"
check_key "Cursor"            kcminputrc Mouse        cursorTheme  "$KM_CURSOR_THEME"
check_key "Plasma theme"      plasmarc  Theme         name         "$exp_plasma"
check_key "Dekorasi library"  kwinrc    org.kde.kdecoration2 library "$KM_DECO_LIBRARY"
check_key "Dekorasi theme"    kwinrc    org.kde.kdecoration2 theme    "$exp_deco"
check_key "Tombol di kanan"   kwinrc    org.kde.kdecoration2 ButtonsOnRight "$KM_BUTTONS_RIGHT"
check_key "Tombol kiri kosong" kwinrc   org.kde.kdecoration2 ButtonsOnLeft  ""

echo
kv_theme="$(km_ini_get "$HOME/.config/Kvantum/kvantum.kvconfig" General theme 2>/dev/null || echo '')"
if [ -n "$kv_theme" ]; then log_ok "Kvantum theme = $kv_theme"; pass=$((pass+1));
else log_err "Kvantum theme kosong"; fail=$((fail+1)); fi

echo
log_info "Lolos: $pass  Gagal: $fail"
if [ "$fail" -gt 0 ]; then
  log_warn "Ada item yang belum cocok. Jalankan ulang install-all.sh atau cek logout/login."
  exit 1
fi
log_ok "Semua terverifikasi."
