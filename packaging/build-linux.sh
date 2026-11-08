#!/usr/bin/env bash
# Construit les paquets Linux de TimeLog :
#   - Debian / Ubuntu : dist/timelog_<version>-1_amd64.deb   (dpkg-deb)
#   - Arch Linux      : dist/timelog-<version>-1-x86_64.pkg.tar.zst (makepkg)
#
# Usage :
#   packaging/build-linux.sh                 # compile Flutter puis fabrique les deux paquets
#   packaging/build-linux.sh --skip-flutter  # réutilise app/build/linux/x64/release/bundle
#   packaging/build-linux.sh --only deb      # ou --only arch
#
# Les fichiers temporaires vont dans packaging/build/, les paquets dans packaging/dist/.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
APP="$ROOT/app"
BUNDLE="$APP/build/linux/x64/release/bundle"
WORK="$HERE/build"
DIST="$HERE/dist"
APP_ID="ch.lukas.timelog"
BIN="timelog"

SKIP_FLUTTER=0
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-flutter) SKIP_FLUTTER=1 ;;
    --only)
      [ $# -ge 2 ] || { echo "--only attend arch ou deb" >&2; exit 2; }
      ONLY="$2"; shift ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $1" >&2; exit 2 ;;
  esac
  shift
done
case "$ONLY" in ""|arch|deb) ;; *) echo "--only accepte arch ou deb" >&2; exit 2 ;; esac

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mattention :\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31merreur :\033[0m %s\n' "$*" >&2; exit 1; }

# Version lue dans pubspec.yaml : « version: 1.1.0+2 » -> 1.1.0
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' "$APP/pubspec.yaml" | head -n1)"
[ -n "$VERSION" ] || die "version introuvable dans app/pubspec.yaml"
log "TimeLog $VERSION"

# 1. Bundle Flutter ----------------------------------------------------------
if [ "$SKIP_FLUTTER" -eq 0 ]; then
  command -v flutter >/dev/null || die "flutter introuvable dans le PATH"
  log "Compilation Flutter (Linux, release)"
  (cd "$APP" && flutter build linux --release)
fi
[ -x "$BUNDLE/$BIN" ] || die "bundle introuvable : $BUNDLE/$BIN (lancer sans --skip-flutter)"

# 2. Arborescence commune (usr/...) ------------------------------------------
# Identique pour les deux formats : l'exécutable vit dans /usr/lib/timelog,
# un lien /usr/bin/timelog pointe dessus (RPATH $ORIGIN/lib reste valide).
make_stage() {
  local dir="$1"
  rm -rf "$dir"
  install -d "$dir/usr/lib/timelog" "$dir/usr/bin" \
    "$dir/usr/share/applications" "$dir/usr/share/icons/hicolor/512x512/apps" \
    "$dir/usr/share/licenses/timelog"
  cp -a "$BUNDLE/." "$dir/usr/lib/timelog/"
  ln -s "../lib/timelog/$BIN" "$dir/usr/bin/$BIN"
  install -m644 "$HERE/common/$APP_ID.desktop" "$dir/usr/share/applications/$APP_ID.desktop"
  install -m644 "$APP/assets/logo.png" "$dir/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
  install -m644 "$ROOT/LICENSE" "$dir/usr/share/licenses/timelog/LICENSE"
  find "$dir" -type d -exec chmod 755 {} +
}

# 3. Paquet Debian ------------------------------------------------------------
build_deb() {
  command -v dpkg-deb >/dev/null || { warn "dpkg-deb absent : .deb ignoré"; return 0; }
  log "Paquet Debian (.deb)"
  local dir="$WORK/deb"
  make_stage "$dir"
  install -d "$dir/usr/share/doc/timelog" "$dir/DEBIAN"
  install -m644 "$ROOT/LICENSE" "$dir/usr/share/doc/timelog/copyright"

  local size
  size="$(du -sk "$dir/usr" | cut -f1)"
  sed -e "s/@VERSION@/$VERSION/" -e "s/@SIZE@/$size/" "$HERE/deb/control.in" > "$dir/DEBIAN/control"
  install -m755 "$HERE/deb/postinst" "$dir/DEBIAN/postinst"
  install -m755 "$HERE/deb/postrm" "$dir/DEBIAN/postrm"

  mkdir -p "$DIST"
  local out="$DIST/timelog_${VERSION}-1_amd64.deb"
  rm -f "$out"
  dpkg-deb --root-owner-group --build "$dir" "$out"
  log "-> $out"
}

# 4. Paquet Arch --------------------------------------------------------------
build_arch() {
  command -v makepkg >/dev/null || { warn "makepkg absent : paquet Arch ignoré"; return 0; }
  log "Paquet Arch Linux (.pkg.tar.zst)"
  local dir="$WORK/arch"
  local stage="$WORK/stage-arch"
  rm -rf "$dir"
  make_stage "$stage"
  mkdir -p "$dir" "$DIST"

  # L'archive source contient l'arborescence usr/ ; PKGBUILD la copie dans le paquet.
  tar -C "$stage" -czf "$dir/timelog-$VERSION-linux-x86_64.tar.gz" usr
  install -m644 "$HERE/arch/PKGBUILD" "$dir/PKGBUILD"
  sed -i "s/^pkgver=.*/pkgver=$VERSION/" "$dir/PKGBUILD"

  (cd "$dir" && PKGDEST="$DIST" makepkg -f --noconfirm --skipinteg)
  log "-> $(ls "$DIST"/timelog-"$VERSION"-1-x86_64.pkg.tar.* 2>/dev/null | head -n1)"
}

if [ -z "$ONLY" ] || [ "$ONLY" = deb ]; then build_deb; fi
if [ -z "$ONLY" ] || [ "$ONLY" = arch ]; then build_arch; fi

log "Terminé. Paquets dans $DIST"
