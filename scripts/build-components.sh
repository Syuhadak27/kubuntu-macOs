#!/usr/bin/env bash
# scripts/build-components.sh — bangun & pasang komponen tema ke $HOME.
# Menyalin aset dari sumber ter- pin (hasil fetch-sources) TANPA mengeksekusi
# installer upstream. Aman, idempotent, dan tanpa sudo.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config
km_pick_tools
km_require_nonroot

log_step "Pembangunan Komponen Tema"

KM_CACHE_DIR="${KM_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kubuntu-macos/src}"
KDE_SRC="$KM_CACHE_DIR/whitesur-kde"
ICO_SRC="$KM_CACHE_DIR/whitesur-icons"
CUR_SRC="$KM_CACHE_DIR/whitesur-cursors"

# Lokasi tujuan user-level
A_DIR="$HOME/.local/share/aurorae/themes"
S_DIR="$HOME/.local/share/color-schemes"
P_DIR="$HOME/.local/share/plasma/desktoptheme"
L_DIR="$HOME/.local/share/plasma/look-and-feel"
KV_DIR="$HOME/.config/Kvantum"
W_DIR="$HOME/.local/share/wallpapers"
I_DIR="$HOME/.local/share/icons"

if [ "$KM_DRY_RUN" = "1" ]; then
  log_info "[dry-run] melewati cek keberadaan sumber (preview)."
else
  for d in "$KDE_SRC" "$ICO_SRC" "$CUR_SRC"; do
    [ -d "$d" ] || die "Sumber belum ada: $d (jalankan fetch-sources.sh dulu)"
  done
fi

mkdir -p "$A_DIR" "$S_DIR" "$P_DIR" "$L_DIR" "$KV_DIR" "$W_DIR" "$I_DIR"

# Salin aman: pertahankan simbolik link & meta (cp -a), dan catat jejak.
_copy() { # <src> <dst>
  local src="$1" dst="$2"
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] cp -a $src -> $dst"
    return 0
  fi
  rm -rf "$dst"
  cp -a "$src" "$dst"
  km_state_record "$dst"
}

# --- 1) WhiteSur-kde: color schemes -----------------------------------------
log_info "Memasang color schemes ..."
_copy "$KDE_SRC/color-schemes/WhiteSur.colors"     "$S_DIR/WhiteSur.colors"
_copy "$KDE_SRC/color-schemes/WhiteSurDark.colors" "$S_DIR/WhiteSurDark.colors"

# --- 2) WhiteSur-kde: plasma desktop theme ----------------------------------
log_info "Memasang plasma desktop theme (panel/menu) ..."
_copy "$KDE_SRC/plasma/desktoptheme/WhiteSur" "$P_DIR/WhiteSur"
# widget icons & weather bawaan ditempel ke dalam tema (seperti upstream)
if [ "$KM_DRY_RUN" != "1" ]; then
  cp -a "$KDE_SRC/plasma/desktoptheme/icons"    "$P_DIR/WhiteSur/icons" 2>/dev/null || true
  cp -a "$KDE_SRC/plasma/desktoptheme/weather"  "$P_DIR/WhiteSur/weather" 2>/dev/null || true
fi

# --- 3) WhiteSur-kde: look-and-feel (global theme) --------------------------
log_info "Memasang look-and-feel (global theme) ..."
_copy "$KDE_SRC/plasma/look-and-feel/com.github.vinceliuice.WhiteSur" \
      "$L_DIR/com.github.vinceliuice.WhiteSur"
_copy "$KDE_SRC/plasma/look-and-feel/com.github.vinceliuice.WhiteSur-dark" \
      "$L_DIR/com.github.vinceliuice.WhiteSur-dark"

# --- 4) WhiteSur-kde: aurorae (dekorasi jendela) ----------------------------
# Replicasi install_aurorae() untuk varian light & dark (window=default, scale='').
build_aurorae() { # <color(''|'-dark')>
  local color="$1"
  local theme_name="WhiteSur${color}"
  local dst="$A_DIR/$theme_name"
  local assets="assets${color}"

  log_info "Memasang aurorae decoration: $theme_name ..."
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] aurorae $theme_name <- main/WhiteSur${color} + common/$assets"
    return 0
  fi
  rm -rf "$dst"; mkdir -p "$dst"
  cp -a "$KDE_SRC/aurorae/main/WhiteSur${color}/." "$dst/"
  cp -a "$KDE_SRC/aurorae/common/$assets/"*.svg "$dst/" 2>/dev/null || true
  cp -a "$KDE_SRC/aurorae/metadata.desktop" "$dst/"
  cp -a "$KDE_SRC/aurorae/metadata.json"   "$dst/"
  cp -a "$KDE_SRC/aurorae/main/WhiteSur${color}rc" "$dst/WhiteSur${color}rc"
  # Ganti nama theme di metadata (aman: hanya mengganti token WhiteSur)
  sed -i "s/WhiteSur/${theme_name}/g" "$dst/metadata.desktop" "$dst/metadata.json"
  km_state_record "$dst"
}
build_aurorae ""       # WhiteSur (light)
build_aurorae "-dark"  # WhiteSur-dark

# --- 5) WhiteSur-kde: Kvantum (gaya Qt) -------------------------------------
log_info "Memasang theme Kvantum ..."
_copy "$KDE_SRC/Kvantum/WhiteSur" "$KV_DIR/WhiteSur"

# --- 6) WhiteSur-kde: wallpaper ---------------------------------------------
log_info "Memasang wallpaper ..."
for wp in WhiteSur-light WhiteSur-dark; do
  if [ -d "$KDE_SRC/wallpaper/$wp" ]; then
    _copy "$KDE_SRC/wallpaper/$wp" "$W_DIR/$wp"
  fi
done

# --- 7) WhiteSur-cursors ----------------------------------------------------
log_info "Memasang cursor theme ..."
# Upstream: cp -pr dist -> icons/WhiteSur-cursors (dist berisi index.theme + cursors/)
_copy "$CUR_SRC/dist" "$I_DIR/WhiteSur-cursors"

# --- 8) WhiteSur-icon-theme (build dari sumber) -----------------------------
# Replikasi install.sh untuk varian dasar (light, penuh) + dark.
build_icons_base() {
  local dst="$I_DIR/WhiteSur"
  log_info "Memasang icon theme: WhiteSur (dasar, penuh) ..."
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] build icon theme WhiteSur"
    return 0
  fi
  rm -rf "$dst"; mkdir -p "$dst/status"
  cp -a "$ICO_SRC/src/index.theme" "$dst/index.theme"
  sed -i "s/WhiteSur/WhiteSur/g" "$dst/index.theme"

  cp -a "$ICO_SRC/src/actions" "$ICO_SRC/src/animations" "$ICO_SRC/src/apps" \
        "$ICO_SRC/src/categories" "$ICO_SRC/src/devices" "$ICO_SRC/src/emotes" \
        "$ICO_SRC/src/emblems" "$ICO_SRC/src/mimes" "$ICO_SRC/src/places" \
        "$ICO_SRC/src/preferences" "$dst/" 2>/dev/null || true
  for s in 16 22 24 32 symbolic; do
    cp -a "$ICO_SRC/src/status/$s" "$dst/status/" 2>/dev/null || true
  done
  rm -f "$dst/places/scalable/user-trash.svg" "$dst/places/scalable/user-trash-full.svg" \
        "$dst/places/scalable/user-trash-dark.svg" "$dst/places/scalable/user-trash-full-dark.svg" 2>/dev/null || true
  # links (simbolik) menunjuk ke file asli
  for l in actions apps categories devices emotes emblems mimes places status preferences; do
    cp -a "$ICO_SRC/links/$l" "$dst/" 2>/dev/null || true
  done
  # @2x variants
  ( cd "$dst"
    for d in actions animations apps categories devices emotes emblems mimes places preferences status; do
      [ -e "$d" ] && ln -sfn "$d" "$d@2x" 2>/dev/null || true
    done
  )
  km_state_record "$dst"
}

build_icons_dark() {
  local dst="$I_DIR/WhiteSur-dark"
  log_info "Memasang icon theme: WhiteSur-dark ..."
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] build icon theme WhiteSur-dark"
    return 0
  fi
  rm -rf "$dst"
  mkdir -p "$dst/apps" "$dst/categories" "$dst/emblems" "$dst/devices" "$dst/mimes" "$dst/places" "$dst/status"

  cp -a "$ICO_SRC/src/actions" "$dst/"
  for s in 16 22 32 symbolic; do cp -a "$ICO_SRC/src/apps/$s" "$dst/apps/" 2>/dev/null || true; done
  for s in 22 symbolic; do cp -a "$ICO_SRC/src/categories/$s" "$dst/categories/" 2>/dev/null || true; done
  cp -a "$ICO_SRC/src/emblems/symbolic" "$dst/emblems/" 2>/dev/null || true
  cp -a "$ICO_SRC/src/mimes/symbolic"   "$dst/mimes/"   2>/dev/null || true
  for s in 16 22 24 32 symbolic; do cp -a "$ICO_SRC/src/devices/$s" "$dst/devices/" 2>/dev/null || true; done
  for s in 16 22 24 scalable symbolic; do cp -a "$ICO_SRC/src/places/$s" "$dst/places/" 2>/dev/null || true; done
  cp -a "$ICO_SRC/src/status/symbolic" "$dst/status/" 2>/dev/null || true

  # Recolor symbolic dari gelap (#363636) ke terang (#dedede)
  if have sed; then
    find "$dst/actions" "$dst/devices" "$dst/places" -type f -path '*/[0-9]*/*.svg' -exec sed -i 's/#363636/#dedede/g' {} + 2>/dev/null || true
    sed -i 's/#363636/#dedede/g' "$dst/apps"/[0-9]*/*.svg 2>/dev/null || true
    sed -i 's/#363636/#dedede/g' "$dst/categories/22"/*.svg 2>/dev/null || true
    find "$dst" -type f -path '*/symbolic/*.svg' -exec sed -i 's/#363636/#dedede/g' {} + 2>/dev/null || true
  fi
  # Tukar ikon trash gelap menjadi terang
  mv -f "$dst/places/scalable/user-trash-dark.svg"      "$dst/places/scalable/user-trash.svg" 2>/dev/null || true
  mv -f "$dst/places/scalable/user-trash-full-dark.svg" "$dst/places/scalable/user-trash-full.svg" 2>/dev/null || true

  # links
  for l in actions devices places apps categories emblems mimes status; do
    cp -a "$ICO_SRC/links/$l/." "$dst/$l/" 2>/dev/null || true
  done

  # Simbolik link kembali ke tema dasar (WhiteSur)
  ( cd "$I_DIR"
    ln -sfn ../WhiteSur/animations "$dst/animations"
    ln -sfn ../WhiteSur/emotes      "$dst/emotes"
    ln -sfn ../WhiteSur/preferences "$dst/preferences"
    ln -sfn ../../WhiteSur/categories/32 "$dst/categories/32"
    ln -sfn ../../WhiteSur/emblems/16 "$dst/emblems/16"
    ln -sfn ../../WhiteSur/emblems/22 "$dst/emblems/22"
    ln -sfn ../../WhiteSur/emblems/24 "$dst/emblems/24"
    ln -sfn ../../WhiteSur/mimes/16 "$dst/mimes/16"
    ln -sfn ../../WhiteSur/mimes/22 "$dst/mimes/22"
    ln -sfn ../../WhiteSur/mimes/scalable "$dst/mimes/scalable"
    ln -sfn ../../WhiteSur/apps/scalable "$dst/apps/scalable"
    ln -sfn ../../WhiteSur/devices/scalable "$dst/devices/scalable"
    for s in 16 22 24 32; do ln -sfn ../../WhiteSur/status/$s "$dst/status/$s"; done
  )
  # @2x
  ( cd "$dst"
    for d in actions animations apps categories devices emotes emblems mimes places preferences status; do
      [ -e "$d" ] && ln -sfn "$d" "$d@2x" 2>/dev/null || true
    done
  )
  # index.theme
  mkdir -p "$dst"
  cp -a "$ICO_SRC/src/index.theme" "$dst/index.theme"
  sed -i "s/WhiteSur/WhiteSur-dark/g" "$dst/index.theme"
  km_state_record "$dst"
}

log_step "Icon Theme"
build_icons_base
build_icons_dark

# Cache ikon GTK (opsional, KDE tidak wajib)
if have gtk-update-icon-cache && [ "$KM_DRY_RUN" != "1" ]; then
  for t in "$I_DIR/WhiteSur" "$I_DIR/WhiteSur-dark" "$I_DIR/WhiteSur-cursors"; do
    gtk-update-icon-cache -f -t "$t" 2>/dev/null || true
  done
fi

echo
log_ok "Semua komponen tematik terpasang."
