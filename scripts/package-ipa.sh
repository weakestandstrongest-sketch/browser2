#!/usr/bin/env bash
# Usage: scripts/package-ipa.sh <path/to/Orbit.app> <output.ipa>
# Wraps a built .app into an (unsigned) .ipa. Sign it afterwards with
# Sideloadly / AltStore / your own certificate before installing.
set -euo pipefail
APP="${1:?path to .app}"
OUT="${2:-Orbit-unsigned.ipa}"
WORK="$(mktemp -d)"
mkdir -p "$WORK/Payload"
cp -R "$APP" "$WORK/Payload/"
OUT_ABS="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
rm -f "$OUT_ABS"
(cd "$WORK" && zip -qry "$OUT_ABS" Payload)
rm -rf "$WORK"
echo "Created $OUT_ABS"
