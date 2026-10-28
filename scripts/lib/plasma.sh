# shellcheck shell=bash
# scripts/lib/plasma.sh — deteksi Plasma 5/6 dan pembungkus tool KDE.
# Sumberkan common.sh dulu, lalu file ini.

if [ -n "${KM_PLASMA_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
KM_PLASMA_LOADED=1

# --- Deteksi versi Plasma ----------------------------------------------------
km_detect_plasma() {
  KM_PLASMA_MAJOR="${KM_PLASMA_MAJOR:-}"
  if [ -n "$KM_PLASMA_MAJOR" ]; then return 0; fi

  local ver=''
  if have plasmashell; then
    ver="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)"
  fi
  # Cadangan: cari kwriteconfig6 -> Plasma 6
  if [ -z "$ver" ]; then
    if have kwriteconfig6 || have kpackagetool6; then ver=6
    elif have kwriteconfig5 || have kpackagetool5; then ver=5
    fi
  fi
  KM_PLASMA_MAJOR="${ver:-6}"
  export KM_PLASMA_MAJOR
}

# Pilih tool sesuai versi Plasma (dipanggil setelah km_detect_plasma).
km_pick_tools() {
  km_detect_plasma
  if [ "$KM_PLASMA_MAJOR" = "6" ]; then
    KM_KWRITECONFIG="${KM_KWRITECONFIG:-$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)}"
    KM_KREADCONFIG="${KM_KREADCONFIG:-$(command -v kreadconfig6 || command -v kreadconfig5 || true)}"
    KM_KPACKAGETOOL="${KM_KPACKAGETOOL:-$(command -v kpackagetool6 || command -v kpackagetool5 || true)}"
    KM_KBUILDSYCOCA="${KM_KBUILDSYCOCA:-$(command -v kbuildsycoca6 || command -v kbuildsycoca5 || true)}"
    KM_LOOKANDFEEL="${KM_LOOKANDFEEL:-$(command -v plasma-apply-lookandfeel || command -v lookandfeeltool || true)}"
  else
    KM_KWRITECONFIG="${KM_KWRITECONFIG:-$(command -v kwriteconfig5 || true)}"
    KM_KREADCONFIG="${KM_KREADCONFIG:-$(command -v kreadconfig5 || true)}"
    KM_KPACKAGETOOL="${KM_KPACKAGETOOL:-$(command -v kpackagetool5 || true)}"
    KM_KBUILDSYCOCA="${KM_KBUILDSYCOCA:-$(command -v kbuildsycoca5 || true)}"
    KM_LOOKANDFEEL="${KM_LOOKANDFEEL:-$(command -v lookandfeeltool || command -v plasma-apply-lookandfeel || true)}"
  fi
  # qdbus untuk reconfigure KWin (nama berbeda antar versi)
  KM_QDBUS="${KM_QDBUS:-$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || command -v qdbus-qt5 || true)}"
  export KM_KWRITECONFIG KM_KREADCONFIG KM_KPACKAGETOOL KM_KBUILDSYCOCA KM_LOOKANDFEEL KM_QDBUS
}

# Tulis key KDE. km_kwrite <file> <grup> <kunci> <nilai>
# Memakai kwriteconfig bila ada, jika tidak pakai km_ini_set.
km_kwrite() {
  local file="$1" group="$2" key="$3" value="$4"
  if [ -n "${KM_KWRITECONFIG:-}" ] && have "$KM_KWRITECONFIG"; then
    run "$KM_KWRITECONFIG" --file "$file" --group "$group" --key "$key" "$value"
  else
    if [ "$KM_DRY_RUN" = "1" ]; then
      log_info "[dry-run] tulis $file [$group] $key=$value"
    else
      km_ini_set "$HOME/.config/$file" "$group" "$key" "$value"
    fi
  fi
}

# Baca key KDE. km_kread <file> <grup> <kunci>
km_kread() {
  local file="$1" group="$2" key="$3"
  if [ -n "${KM_KREADCONFIG:-}" ] && have "$KM_KREADCONFIG"; then
    "$KM_KREADCONFIG" --file "$file" --group "$group" --key "$key" 2>/dev/null || true
  else
    km_ini_get "$HOME/.config/$file" "$group" "$key"
  fi
}

# Terapkan look-and-feel (global theme) beserta layout bawaannya.
km_apply_lookandfeel() {
  local package_id="$1"
  if [ -z "${KM_LOOKANDFEEL:-}" ] || ! have "$KM_LOOKANDFEEL"; then
    log_warn "plasma-apply-lookandfeel/lookandfeeltool tidak tersedia; lewati penerapan global theme."
    return 0
  fi
  run "$KM_LOOKANDFEEL" -a "$package_id"
}

# Bangun ulang ikon cache KDE.
km_rebuild_sycoca() {
  if [ -n "${KM_KBUILDSYCOCA:-}" ] && have "$KM_KBUILDSYCOCA"; then
    run "$KM_KBUILDSYCOCA" || log_warn "kbuildsycoca gagal (tidak fatal)."
  fi
}

# Minta KWin memuat ulang konfigurasinya (decoration, tombol, dsb).
km_reconfigure_kwin() {
  if [ -n "${KM_QDBUS:-}" ] && have "$KM_QDBUS"; then
    run "$KM_QDBUS" org.kde.KWin /KWin reconfigure || log_warn "reconfigure KWin via qdbus gagal."
  else
    log_warn "qdbus tidak tersedia; perubahan KWin aktif setelah logout/login."
  fi
}

# Terapkan wallpaper (best-effort; lewati bila tool tidak ada).
km_apply_wallpaper() {
  local img="$1"
  local apply
  apply="$(command -v plasma-apply-wallpaperimage || true)"
  if [ -n "$apply" ]; then
    run "$apply" "$img" || log_warn "plasma-apply-wallpaperimage gagal."
  else
    log_warn "plasma-apply-wallpaperimage tidak ada; atur wallpaper manual."
  fi
}
