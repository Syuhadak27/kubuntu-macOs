#!/usr/bin/env bash
# scripts/setup-dock.sh — pastikan panel atas (menu bar) + dock bawah ala macOS
# terpasang. Layout WhiteSur sudah menyerupai macOS; script ini hanya memastikan
# layout diterapkan dan menyetel launcher dock sesuai KM_DOCK_LAUNCHERS.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/plasma.sh"
km_load_config
km_pick_tools
km_require_nonroot

log_step "Pengaturan Panel & Dock (macOS)"

if [ "$KM_NO_LAYOUT" = "1" ]; then
  log_warn "Melewati pengaturan layout (--no-layout)."
  exit 0
fi

# Terapkan ulang look-and-feel untuk memastikan layout panel (menu bar atas +
# dock bawah) dibuat sesuai template WhiteSur.
if [ "$KM_VARIANT" = "dark" ]; then
  LF_ID="$KM_LOOKFEEL_DARK"
else
  LF_ID="$KM_LOOKFEEL_LIGHT"
fi

if [ -n "${KM_LOOKANDFEEL:-}" ] && have "$KM_LOOKANDFEEL"; then
  log_info "Menerapkan layout global theme: $LF_ID"
  # --reset-layout memaksa panel mengikuti template theme (macOS-like).
  if "$KM_LOOKANDFEEL" --help 2>&1 | grep -q -- '--reset-layout'; then
    run "$KM_LOOKANDFEEL" -a "$LF_ID" --reset-layout \
      || log_warn "Penerapan layout gagal; panel lama dipertahankan."
  else
    run "$KM_LOOKANDFEEL" -a "$LF_ID" \
      || log_warn "Penerapan look-and-feel gagal."
  fi
else
  log_warn "Tool look-and-feel tidak tersedia; atur panel/dock manual di System Settings."
fi

# Catat launcher dock untuk referensi pengguna.
log_info "Launcher dock (KM_DOCK_LAUNCHERS):"
printf '  - %s\n' "${KM_DOCK_LAUNCHERS[@]:-}"

echo
log_ok "Panel atas + dock bawah siap. Sesuaikan isi dock dengan drag ikon."
