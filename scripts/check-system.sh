#!/usr/bin/env bash
# scripts/check-system.sh — validasi OS, Plasma, ruang disk, dan tool wajib.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config

log_step "Pemeriksaan Sistem"

fail=0

# 1) OS: Kubuntu/Ubuntu
. /etc/os-release 2>/dev/null || true
os_id="${ID:-unknown}"
os_like="${ID_LIKE:-}"
log_info "OS terdeteksi: ${PRETTY_NAME:-$os_id}"
case "$os_id $os_like" in
  *ubuntu*|*kubuntu*|*debian*) log_ok "Distro cocok (Ubuntu/Debian turunan)." ;;
  *) log_warn "Distro '$os_id' mungkin tidak teruji. Lanjut saja." ;;
esac

# 2) Plasma harus terpasang
if have plasmashell; then
  km_detect_plasma
  log_ok "Plasma terdeteksi: versi $KM_PLASMA_MAJOR ($(plasmashell --version 2>/dev/null | head -1))"
else
  if [ "$KM_DRY_RUN" = "1" ]; then
    log_warn "plasmashell tidak ditemukan (preview dry-run; di Kubuntu asli harus ada)."
  else
    log_err "plasmashell tidak ditemukan. Tema ini khusus KDE Plasma (Kubuntu)."
    fail=1
  fi
fi

# 3) Tool inti yang dibutuhkan
km_pick_tools
missing=()
for c in git curl tar gzip python3 sha256sum flock awk sed grep find mktemp; do
  have "$c" || missing+=("$c")
done
if [ "${#missing[@]}" -gt 0 ]; then
  log_warn "Tool inti belum ada: ${missing[*]} (akan dipasang oleh install-deps.sh)"
fi

# Tool KDE bersifat opsional tapi dicatat agar pengguna tahu
for pair in "KM_LOOKANDFEEL:plasma-apply-lookandfeel/lookandfeeltool" \
            "KM_KWRITECONFIG:kwriteconfig" "KM_QDBUS:qdbus"; do
  var="${pair%%:*}"; label="${pair##*:}"
  if [ -n "${!var:-}" ] && have "${!var}"; then
    log_ok "$label tersedia (${!var})"
  else
    log_warn "$label belum tersedia ($label)"
  fi
done

# 4) Ruang disk di $HOME (toleran thd df yang berbeda antar sistem)
free_mb=""
free_mb="$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2{print $4}')" || true
if [ -z "$free_mb" ] || ! [ "$free_mb" -eq "$free_mb" ] 2>/dev/null; then
  free_mb="$(df -m "$HOME" 2>/dev/null | awk 'NR==2{print $4}')" || true
fi
if [ -n "$free_mb" ] && [ "$free_mb" -eq "$free_mb" ] 2>/dev/null; then
  if [ "$free_mb" -lt "$KM_MIN_FREE_MB" ]; then
    log_err "Ruang disk kurang: ${free_mb}MB tersedia, minimal ${KM_MIN_FREE_MB}MB."
    fail=1
  else
    log_ok "Ruang disk cukup: ${free_mb}MB tersedia."
  fi
else
  log_warn "Tidak bisa membaca ruang disk; lanjut."
fi

# 5) Jaringan (untuk ambil sumber tema)
if have curl && curl -fsSL --max-time 8 -o /dev/null https://github.com 2>/dev/null; then
  log_ok "Koneksi ke github.com OK."
else
  log_warn "Tidak bisa menghubungi github.com. Tahap 'fetch-sources' mungkin gagal."
fi

echo
if [ "$fail" -ne 0 ]; then
  die "Pemeriksaan sistem gagal. Perbaiki dulu item di atas."
fi
log_ok "Sistem siap."
