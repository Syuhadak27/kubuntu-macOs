#!/usr/bin/env bash
# scripts/install-deps.sh — pasang paket yang belum ada (butuh sudo).
# Hanya memasang yang benar-benar hilang, dan hanya setelah persetujuan user.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config
km_pick_tools

log_step "Pemasangan Dependensi"

if ! have apt-get; then
  log_warn "apt-get tidak ditemukan; lewati pemasangan paket."
  exit 0
fi

# Kumpulkan paket yang belum terpasang ---------------------------------------
pkgs=()
declare -A need=()
for c in git;     do have git     || need[git]=1;     done
for c in curl;    do have curl    || need[curl]=1;    done
for c in tar;     do have tar     || need[tar]=1;     done
for c in gzip;    do have gzip    || need[gzip]=1;    done
for c in python3; do have python3 || need[python3]=1; done
for c in unzip;   do have unzip   || need[unzip]=1;   done
for k in "${!need[@]}"; do pkgs+=("$k"); done

# Tool konfigurasi KDE sesuai Plasma
km_detect_plasma
if [ "$KM_PLASMA_MAJOR" = "6" ]; then
  have kwriteconfig6 || have kwriteconfig5 || pkgs+=("$KM_PLASMA6_CONFIG_PACKAGE")
  have kvantumtheme || pkgs+=("$KM_PLASMA6_KVANTUM_PACKAGE")
else
  have kwriteconfig5 || pkgs+=("$KM_PLASMA5_CONFIG_PACKAGE")
  have kvantumtheme  || pkgs+=("$KM_PLASMA5_KVANTUM_PACKAGE")
fi

# Font (opsional tapi disarankan)
if ! have fc-list || ! fc-list 2>/dev/null | grep -qi 'Inter'; then
  pkgs+=("$KM_FONT_PACKAGE")
fi

# Unik-kan
if [ "${#pkgs[@]}" -gt 0 ]; then
  printf -v uniq_pkgs '%s\n' "${pkgs[@]}" | sort -u > /tmp/km-pkgs.$$ || true
  mapfile -t pkgs < <(grep -v '^$' /tmp/km-pkgs.$$ || true)
  rm -f /tmp/km-pkgs.$$
fi

if [ "${#pkgs[@]}" -eq 0 ]; then
  log_ok "Semua dependensi sudah terpasang."
  exit 0
fi

log_info "Paket yang akan dipasang: ${pkgs[*]}"

if ! have sudo; then
  log_warn "'sudo' tidak tersedia. Pasang manual: sudo apt install ${pkgs[*]}"
  exit 0
fi

if ! confirm "Pasang paket ini sekarang (butuh sudo)?"; then
  log_warn "User membatalkan pemasangan paket. Beberapa fitur mungkin tidak berfungsi penuh."
  exit 0
fi

run sudo apt-get update -y || log_warn "apt-get update gagal; coba lanjut."
run sudo apt-get install -y "${pkgs[@]}" || {
  log_warn "Sebagian paket gagal dipasang. Lanjut tanpa yang gagal."
}

log_ok "Dependensi selesai."
