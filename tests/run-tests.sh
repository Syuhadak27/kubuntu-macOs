#!/usr/bin/env bash
# tests/run-tests.sh — uji cepat tanpa menyentuh sistem nyata.
# Menjalankan: cek sintaks bash, muat konfigurasi, uji fungsi INI,
# parse repos.conf, dan dry-run pipeline penuh. Tidak butuh Plasma/apt.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0; fail=0
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$1"; fail=$((fail+1)); }

echo "=============================================="
echo " Kubuntu-macOS — test harness"
echo "=============================================="

# --- 1) Sintaks bash --------------------------------------------------------
echo
echo "[1] Sintaks bash (bash -n)"
for f in install-all.sh scripts/*.sh scripts/lib/*.sh; do
  if bash -n "$f" 2>/dev/null; then ok "bash -n $f"; else bad "bash -n $f"; fi
done

# --- 2) Muat konfigurasi & variabel kunci -----------------------------------
echo
echo "[2] Konfigurasi"
if KM_PROJECT_NAME="$(bash -c 'source scripts/lib/common.sh; km_load_config; echo "$KM_PROJECT_NAME"')" \
   && [ -n "$KM_PROJECT_NAME" ]; then
  ok "km_load_config memuat defaults/dependencies"
else
  bad "km_load_config gagal"
fi

for var in KM_THEME_LIGHT KM_THEME_DARK KM_LOOKFEEL_LIGHT KM_LOOKFEEL_DARK \
           KM_ICON_THEME KM_CURSOR_THEME KM_KVANTUM_LIGHT KM_KVANTUM_DARK \
           KM_FONT_FAMILY KM_FONT_STRING KM_BUTTONS_RIGHT KM_DECO_LIBRARY; do
  val="$(bash -c "source scripts/lib/common.sh; km_load_config; printf '%s' \"\${$var:-}\"" 2>/dev/null)"
  if [ -n "$val" ]; then ok "$var = $val"; else bad "$var kosong"; fi
done

# --- 3) Fungsi INI writer/reader --------------------------------------------
echo
echo "[3] km_ini_set / km_ini_get"
TF="$(mktemp)"
bash -c "
  source scripts/lib/common.sh
  km_load_config
  km_ini_set '$TF' General ColorScheme WhiteSur
  km_ini_set '$TF' org.kde.kdecoration2 ButtonsOnRight IAX
  km_ini_set '$TF' org.kde.kdecoration2 ButtonsOnLeft ''
" 
c1="$(bash -c "source scripts/lib/common.sh; km_ini_get '$TF' General ColorScheme")"
c2="$(bash -c "source scripts/lib/common.sh; km_ini_get '$TF' org.kde.kdecoration2 ButtonsOnRight")"
[ "$c1" = "WhiteSur" ] && ok "INI set/get ColorScheme=WhiteSur" || bad "INI ColorScheme dapat '$c1'"
[ "$c2" = "IAX" ] && ok "INI set/get ButtonsOnRight=IAX" || bad "INI ButtonsOnRight dapat '$c2'"
rm -f "$TF"

# --- 4) Parse repos.conf ----------------------------------------------------
echo
echo "[4] Parse repos.conf"
n="$(grep -vcE '^\s*(#|$)' config/repos.conf)"
if [ "$n" -ge 3 ]; then ok "minimal 3 baris sumber ($n)"; else bad "hanya $n baris sumber"; fi
while IFS='|' read -r name url branch pin req _lic _desc; do
  case "$name" in ''|\#*) continue ;; esac
  [[ "$url" == https://github.com/* ]] && ok "$name url valid" || bad "$name url: $url"
  [[ "$pin" =~ ^[0-9a-f]{40}$ ]] && ok "$name pin 40-hex" || bad "$name pin: $pin"
done < config/repos.conf

# --- 5) Dry-run pipeline penuh ----------------------------------------------
echo
echo "[5] Dry-run pipeline (light & dark)"
if KM_YES=1 KM_DRY_RUN=1 bash install-all.sh --yes --dry-run --no-deps >/dev/null 2>&1; then
  ok "dry-run light exit 0"
else
  bad "dry-run light gagal"
fi
if KM_YES=1 KM_DRY_RUN=1 bash install-all.sh --yes --dry-run --no-deps --dark >/dev/null 2>&1; then
  ok "dry-run dark exit 0"
else
  bad "dry-run dark gagal"
fi

# --- 6) Uninstall tidak error saat kosong -----------------------------------
echo
echo "[6] uninstall --dry-run"
if KM_YES=1 KM_DRY_RUN=1 bash scripts/uninstall.sh >/dev/null 2>&1; then
  ok "uninstall dry-run exit 0"
else
  bad "uninstall dry-run gagal"
fi

echo
echo "=============================================="
printf ' Total: %d pass, %d fail\n' "$pass" "$fail"
echo "=============================================="
[ "$fail" -eq 0 ]
