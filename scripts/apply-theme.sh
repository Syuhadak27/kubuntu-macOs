#!/usr/bin/env bash
# scripts/apply-theme.sh — terapkan semua pengaturan tampilan ke sesi user.
# Font, skema warna, ikon, cursor, dekorasi jendela (tombol di kanan), Kvantum,
# wallpaper. Idempotent; aman dijalankan berulang.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config
km_pick_tools
km_require_nonroot

log_step "Penerapan Tema"

KM_CACHE_DIR="${KM_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kubuntu-macos/src}"

# Tentukan varian -------------------------------------------------------------
if [ "$KM_VARIANT" = "dark" ]; then
  LF_ID="$KM_LOOKFEEL_DARK"
  COLOR="$KM_COLOR_DARK"
  ICON="$KM_ICON_THEME-dark"
  KVANTUM_THEME="$KM_KVANTUM_DARK"
  KVANTUM_STYLE="kvantum-dark"
  PLASMA_THEME="$KM_THEME_DARK"
  WALLPAPER="$HOME/.local/share/wallpapers/WhiteSur-dark"
else
  LF_ID="$KM_LOOKFEEL_LIGHT"
  COLOR="$KM_COLOR_LIGHT"
  ICON="$KM_ICON_THEME"
  KVANTUM_THEME="$KM_KVANTUM_LIGHT"
  KVANTUM_STYLE="kvantum"
  PLASMA_THEME="$KM_THEME_LIGHT"
  WALLPAPER="$HOME/.local/share/wallpapers/WhiteSur-light"
fi
log_info "Varian: $KM_VARIANT  (look-and-feel: $LF_ID)"

# Backup konfigurasi sekali sebelum diubah (untuk uninstall) ------------------
km_backup_configs

# --- 1) Font Inter -----------------------------------------------------------
log_info "Memasang & menerapkan font: $KM_FONT_FAMILY"
if have fc-list && fc-list 2>/dev/null | grep -qi "$KM_FONT_FAMILY"; then
  log_ok "Font $KM_FONT_FAMILY sudah terpasang."
else
  # Coba apt (dipasang oleh install-deps), jika tidak ada unduh dari GitHub.
  if have fc-cache; then
    FONT_DIR="$HOME/.local/share/fonts/Inter"
    if [ "$KM_DRY_RUN" = "1" ]; then
      log_info "[dry-run] unduh Inter ke $FONT_DIR"
    else
      mkdir -p "$FONT_DIR"
      ZIP_URL="${KM_INTER_URL:-https://github.com/rsms/inter/releases/download/v4.0/Inter-4.0.zip}"
      TMPZIP="$(mktemp /tmp/inter.XXXXXX.zip)"
      if curl -fsSL --max-time 120 "$ZIP_URL" -o "$TMPZIP" 2>/dev/null; then
        if have unzip && unzip -oq "$TMPZIP" -d "$FONT_DIR" 2>/dev/null; then
          fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
          log_ok "Inter diunduh & dipasang ke $FONT_DIR"
        else
          log_warn "Gagal ekstrak Inter (butuh 'unzip'). Lewati."
        fi
      else
        log_warn "Gagal mengunduh Inter. Lanjut tanpa font kustom."
      fi
      rm -f "$TMPZIP"
    fi
  fi
fi

# Terapkan font ke kdeglobals (beberapa key yang dipakai Qt/KDE)
km_kwrite kdeglobals General font            "$KM_FONT_STRING"
km_kwrite kdeglobals General fixed           "$KM_FONT_STRING"
km_kwrite kdeglobals General smallestReadableFont "$KM_FONT_STRING"
km_kwrite kdeglobals General toolBarFont     "$KM_FONT_STRING"
km_kwrite kdeglobals General menuFont        "$KM_FONT_STRING"

# --- 2) Global theme / look-and-feel ----------------------------------------
# Terapkan via tool resmi (mengatur warna, ikon, cursor, dekorasi, wallpaper,
# panel & dock sesuai layout bawaan WhiteSur yang sudah menyerupai macOS).
km_apply_lookandfeel "$LF_ID"

# --- 3) Set manual semua key tampilan (memastikan konsisten walau tool absen) -
log_info "Menyetel skema warna, ikon, cursor, gaya ..."
km_kwrite kdeglobals General ColorScheme     "$COLOR"
km_kwrite kdeglobals Icons  Theme            "$ICON"
km_kwrite kdeglobals KDE   widgetStyle      "$KVANTUM_STYLE"
km_kwrite kcminputrc Mouse  cursorTheme     "$KM_CURSOR_THEME"
km_kwrite kcminputrc Mouse  cursorSize      "${KM_CURSOR_SIZE:-24}"
km_kwrite plasmarc  Theme   name            "$PLASMA_THEME"

# --- 4) Kvantum theme selection ---------------------------------------------
if [ "$KM_DRY_RUN" = "1" ]; then
  log_info "[dry-run] set Kvantum theme=$KVANTUM_THEME"
else
  mkdir -p "$HOME/.config/Kvantum"
  km_ini_set "$HOME/.config/Kvantum/kvantum.kvconfig" General theme "$KVANTUM_THEME"
  log_ok "Kvantum theme -> $KVANTUM_THEME"
fi

# --- 5) Dekorasi jendela: aurorae + tombol di KANAN -------------------------
# KWin memetakan __aurorae__svg__<nama> -> ~/.local/share/aurorae/themes/<nama>/.
log_info "Menyetel dekorasi jendela (aurorae) & posisi tombol ..."
DECO_THEME="__aurorae__svg__WhiteSur"
[ "$KM_VARIANT" = "dark" ] && DECO_THEME="__aurorae__svg__WhiteSur-dark"

km_kwrite kwinrc org.kde.kdecoration2 library "$KM_DECO_LIBRARY"
km_kwrite kwinrc org.kde.kdecoration2 theme    "$DECO_THEME"

# Posisi tombol: user minta minimize/maximize di KANAN.
# KWin: I=Minimize, A=Maximize, X=Close.
if [ "$KM_BUTTON_SIDE" = "left" ]; then
  km_kwrite kwinrc org.kde.kdecoration2 ButtonsOnLeft  "$KM_BUTTONS_LEFT"
  km_kwrite kwinrc org.kde.kdecoration2 ButtonsOnRight ""
else
  km_kwrite kwinrc org.kde.kdecoration2 ButtonsOnLeft  ""
  km_kwrite kwinrc org.kde.kdecoration2 ButtonsOnRight "$KM_BUTTONS_RIGHT"
fi
log_ok "Tombol jendela di sisi: $KM_BUTTON_SIDE (kanan = IAX: minimize, maximize, close)"

# --- 6) Wallpaper ------------------------------------------------------------
if [ -d "$WALLPAPER" ]; then
  IMG="$(find "$WALLPAPER" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) 2>/dev/null | head -1 || true)"
  if [ -n "$IMG" ]; then
    km_apply_wallpaper "$IMG"
  else
    log_warn "Tidak ada gambar wallpaper di $WALLPAPER"
  fi
else
  log_warn "Wallpaper $WALLPAPER belum terpasang (jalankan build-components)."
fi

# --- 7) Muat ulang cache & KWin ---------------------------------------------
km_rebuild_sycoca
km_reconfigure_kwin

echo
log_ok "Tema diterapkan. Beberapa perubahan (font/ikon) paling sempurna setelah logout/login."
