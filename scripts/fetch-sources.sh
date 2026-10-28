#!/usr/bin/env bash
# scripts/fetch-sources.sh — clone repo GitHub yang di- pin ke dalam cache lokal.
# Tidak pernah mengeksekusi installer upstream; hanya mengunduh sumber.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
km_load_config

log_step "Pengambilan Sumber Tema"

KM_CACHE_DIR="${KM_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/kubuntu-macos/src}"
export KM_CACHE_DIR
log_info "Direktori cache: $KM_CACHE_DIR"

if ! have git; then
  die "git tidak tersedia. Jalankan install-deps.sh dulu."
fi

mkdir -p "$KM_CACHE_DIR"

# Format repos.conf: name|url|branch|pin|required,paths|license|description
fetch_one() {
  local name="$1" url="$2" branch="$3" pin="$4"
  local dir="$KM_CACHE_DIR/$name"

  if [ "$KM_DRY_RUN" = "1" ]; then
    log_info "[dry-run] clone $name @ $pin -> $dir"
    return 0
  fi

  if [ -d "$dir/.git" ]; then
    local cur
    cur="$(git -C "$dir" rev-parse HEAD 2>/dev/null || echo '')"
    if [ "$cur" = "$pin" ]; then
      log_ok "$name sudah ada & cocok ($pin)."
      return 0
    fi
    log_info "$name ada tapi commit berbeda; sinkron ke $pin ..."
    git -C "$dir" fetch --quiet --depth 1 origin "$pin" >/dev/null 2>&1 \
      && git -C "$dir" checkout --quiet "$pin" >/dev/null 2>&1 \
      && { log_ok "$name disinkronkan ke $pin."; return 0; }
    log_warn "$name gagal disinkron; hapus dan ulangi."
    rm -rf "$dir"
  fi

  log_info "Clone $name ($branch) ..."
  if ! git clone --quiet --filter=blob:none --no-checkout "$url" "$dir" >/dev/null 2>&1; then
    log_err "Gagal clone $url"
    return 1
  fi
  git -C "$dir" fetch --quiet --depth 1 origin "$pin" >/dev/null 2>&1 || true
  if ! git -C "$dir" checkout --quiet "$pin" >/dev/null 2>&1; then
    # cadangan: fetch penuh lalu checkout
    git -C "$dir" fetch --quiet origin >/dev/null 2>&1 || true
    git -C "$dir" checkout --quiet "$pin" >/dev/null 2>&1 || {
      log_err "Gagal checkout commit $pin untuk $name"; return 1; }
  fi
  log_ok "$name ter-clone @ $pin"
}

# Verifikasi path wajib ada setelah clone.
verify_paths() { # <name> <comma,separated,paths>
  local name="$1" paths="$2" dir="$KM_CACHE_DIR/$name" p missing=0
  [ "$KM_DRY_RUN" = "1" ] && return 0
  IFS=',' read -r -a arr <<< "$paths"
  for p in "${arr[@]}"; do
    [ -e "$dir/$p" ] || { log_err "$name: path wajib hilang -> $p"; missing=1; }
  done
  [ "$missing" = "0" ] && log_ok "$name: semua path wajib ada."
  return "$missing"
}

status=0
while IFS='|' read -r name url branch pin required _lic _desc; do
  # Lewati baris komentar / kosong
  case "$name" in ''|\#*) continue ;; esac
  fetch_one "$name" "$url" "$branch" "$pin" || { status=1; continue; }
  verify_paths "$name" "$required" || status=1
done < "$KM_ROOT/config/repos.conf"

echo
if [ "$status" -ne 0 ]; then
  die "Pengambilan sumber gagal. Periksa koneksi/jaringan lalu coba lagi."
fi
log_ok "Semua sumber siap di $KM_CACHE_DIR"
