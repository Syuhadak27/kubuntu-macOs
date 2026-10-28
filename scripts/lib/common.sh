# shellcheck shell=bash
# scripts/lib/common.sh — utilitas bersama untuk Kubuntu-macOS.
# Sumberkan file ini dari script lain:  source "$(dirname "$0")/lib/common.sh"

# Guard supaya tidak di-source dua kali
if [ -n "${KM_COMMON_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
KM_COMMON_LOADED=1

# --- Lokasi root proyek (Kubuntu-macOS/) -------------------------------------
# File ini berada di scripts/lib/, jadi naik dua level.
KM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export KM_ROOT

# --- Warna & logging ---------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_BOLD=$'\033[1m'
else
  C_RESET=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_BOLD=''
fi

_km_ts() { date '+%H:%M:%S'; }
log_info() { printf '%s[%s] %s%s\n' "$C_BLUE"  "$(_km_ts)" "$*" "$C_RESET"; }
log_ok()   { printf '%s[%s] ✓ %s%s\n' "$C_GREEN" "$(_km_ts)" "$*" "$C_RESET"; }
log_warn() { printf '%s[%s] ! %s%s\n' "$C_YELLOW" "$(_km_ts)" "$*" "$C_RESET" >&2; }
log_err()  { printf '%s[%s] ✗ %s%s\n' "$C_RED"  "$(_km_ts)" "$*" "$C_RESET" >&2; }
log_step() { printf '\n%s=== %s ===%s\n' "$C_BOLD$C_CYAN" "$*" "$C_RESET"; }
die()      { log_err "$*"; exit 1; }

# --- Flag global (di- set oleh install-all.sh) -------------------------------
KM_DRY_RUN="${KM_DRY_RUN:-0}"    # 1 = hanya tampilkan, jangan eksekusi
KM_YES="${KM_YES:-0}"            # 1 = tidak perlu konfirmasi
KM_VARIANT="${KM_VARIANT:-light}" # light | dark
KM_NO_LAYOUT="${KM_NO_LAYOUT:-0}" # 1 = jangan ganti layout panel/dock
KM_BUTTON_SIDE="${KM_BUTTON_SIDE:-right}" # right | left

# --- Utilitas dasar ----------------------------------------------------------
have() { command -v "$1" >/dev/null 2>&1; }

# Jalankan perintah; di dry-run hanya dicetak.
run() {
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] $*"
    return 0
  fi
  "$@"
}

# Konfirmasi pengguna (lewati bila KM_YES=1 atau dry-run).
confirm() {
  local prompt="${1:-Lanjutkan?}"
  if [ "$KM_YES" = "1" ] || [ "$KM_DRY_RUN" = "1" ]; then
    return 0
  fi
  local ans=''
  read -r -p "$prompt [y/N] " ans || true
  case "$ans" in
    y|Y|yes|YES|Ya|YA) return 0 ;;
    *) return 1 ;;
    esac
}

# Penulis INI garis-per-baris (cadangan bila kwriteconfig tidak tersedia).
# Pakai: km_ini_set <file> <grup> <kunci> <nilai>
km_ini_set() {
  local file="$1" group="$2" key="$3" value="$4"
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || printf '[%s]\n' "$group" > "$file"
  KM_INI_FILE="$file" KM_INI_GROUP="$group" KM_INI_KEY="$key" KM_INI_VALUE="$value" \
  python3 - <<'PY'
import os, re
f=os.environ['KM_INI_FILE']; g=os.environ['KM_INI_GROUP']
k=os.environ['KM_INI_KEY']; v=os.environ['KM_INI_VALUE']
try:
    lines=open(f, encoding='utf-8').read().splitlines()
except FileNotFoundError:
    lines=[]
def isgrp(s): 
    s=s.strip()
    return s.startswith('[') and s.endswith(']')
out=[]; ingrp=False; done=False; grpidx=None
for i,ln in enumerate(lines):
    if isgrp(ln):
        # tutup blok grup lama -> sisipkan kunci jika belum ada
        if ingrp and not done:
            out.append(f'{k}={v}'); done=True
        out.append(ln)
        ingrp = (ln.strip()[1:-1].strip()==g)
        if ingrp: grpidx=len(out)
    else:
        out.append(ln)
if not lines:
    out=[f'[{g}]', f'{k}={v}']; done=True
elif ingrp and not done:
    out.append(f'{k}={v}'); done=True
elif not done:
    # grup tidak ada sama sekali -> tambahkan di akhir
    if out and out[-1].strip(): out.append('')
    out.append(f'[{g}]'); out.append(f'{k}={v}')
open(f,'w',encoding='utf-8').write('\n'.join(out)+'\n')
PY
}

# Baca INI sederhana: km_ini_get <file> <grup> <kunci>
km_ini_get() {
  local file="$1" group="$2" key="$3"
  [ -f "$file" ] || return 0
  KM_INI_FILE="$file" KM_INI_GROUP="$group" KM_INI_KEY="$key" \
  python3 - <<'PY'
import os
f=os.environ['KM_INI_FILE']; g=os.environ['KM_INI_GROUP']; k=os.environ['KM_INI_KEY']
cur=None
for ln in open(f, encoding='utf-8'):
    s=ln.strip()
    if s.startswith('[') and s.endswith(']'):
        cur=s[1:-1].strip(); continue
    if cur==g and '=' in s:
        kk,_,vv=s.partition('=')
        if kk.strip()==k:
            print(vv.strip()); break
PY
}

# Backup berkas konfigurasi KDE sekali sebelum diubah (untuk uninstall).
KM_BACKUP_DIR="${KM_BACKUP_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/kubuntu-macos/backup}"
km_backup_configs() {
  local f base
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] backup konfigurasi -> $KM_BACKUP_DIR"
    return 0
  fi
  mkdir -p "$KM_BACKUP_DIR"
  for f in kdeglobals kwinrc kcminputrc plasmarc; do
    [ -f "$HOME/.config/$f" ] || continue
    base="$(date '+%Y%m%d-%H%M%S')-$f"
    cp -a "$HOME/.config/$f" "$KM_BACKUP_DIR/$base" 2>/dev/null || true
    ln -sf "$KM_BACKUP_DIR/$base" "$KM_BACKUP_DIR/latest-$f" 2>/dev/null || true
  done
  if [ -f "$HOME/.config/Kvantum/kvantum.kvconfig" ]; then
    mkdir -p "$KM_BACKUP_DIR/Kvantum"
    cp -a "$HOME/.config/Kvantum/kvantum.kvconfig" \
      "$KM_BACKUP_DIR/Kvantum/$(date '+%Y%m%d-%H%M%S')-kvantum.kvconfig" 2>/dev/null || true
  fi
  log_ok "Konfigurasi di-backup ke $KM_BACKUP_DIR"
}

# Catat jejak instalasi agar uninstall bisa membersihkan.
KM_STATE_DIR="${KM_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/kubuntu-macos}"
km_state_record() { # km_state_record <path>
  [ "$KM_DRY_RUN" = "1" ] && return 0
  mkdir -p "$KM_STATE_DIR"
  printf '%s\n' "$1" >> "$KM_STATE_DIR/installed-paths.txt"
}

# Pastikan berjalan sebagai user biasa (bukan root) untuk tahap tema.
km_require_nonroot() {
  if [ "$(id -u)" = "0" ]; then
    die "Jalankan sebagai user biasa (bukan sudo). Hanya 'install-deps.sh' yang butuh sudo."
  fi
}

# Muat konfigurasi proyek (hanya file shell; repos.conf adalah data, dibaca
# baris-per-baris oleh fetch-sources.sh, jangan di-source).
km_load_config() {
  local f
  for f in defaults.conf dependencies.conf; do
    [ -f "$KM_ROOT/config/$f" ] || die "File konfigurasi hilang: config/$f"
    # shellcheck disable=SC1090
    source "$KM_ROOT/config/$f"
  done
  [ -f "$KM_ROOT/config/repos.conf" ] || die "File konfigurasi hilang: config/repos.conf"
}
