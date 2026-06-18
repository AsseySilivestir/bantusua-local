#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  pack-windows.sh — Assemble the self-contained Windows zip
#
#  Produces:  dist/chatbantu-windows-x64.zip
#
#  The zip contains everything a Windows user needs:
#    - bantu.exe
#    - server.b
#    - public/ (frontend)
#    - runtime DLLs (sqlite3, libcurl, libc++, libunwind, libwinpthread)
#    - start.bat, stop.bat, reset-db.bat, README.md
#
#  After packing, upload the zip as a GitHub Release asset so users
#  can grab it from https://github.com/AsseySilivestir/bantusua-local/releases
# ─────────────────────────────────────────────────────────────────────
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WINDEPS="$ROOT/win-deps"
MINGW="${MINGW_PREFIX:-/tmp/my-project/scripts/build-win/llvm-mingw-20230614-ucrt-ubuntu-20.04-x86_64}"

DIST="$ROOT/dist"
STAGE="$DIST/chatbantu-windows-x64"

echo "════════════════════════════════════════════════════════════════"
echo "  Packing ChatBantu for Windows x64"
echo "  root:      $ROOT"
echo "  win-deps:  $WINDEPS"
echo "  staging:   $STAGE"
echo "════════════════════════════════════════════════════════════════"

# ─── 1. Rebuild bantu.exe (always fresh) ────────────────────────────
echo
echo "── [1/5] Rebuilding bantu.exe ──"
cd "$ROOT/bantu-src/compiler"
./build-win.sh > /tmp/build-win.log 2>&1 || {
    echo "[FAIL] build-win.sh failed. Tail of log:"
    tail -30 /tmp/build-win.log
    exit 1
}
BANTU_EXE="$ROOT/bantu-src/compiler/build/bantu.exe"
test -f "$BANTU_EXE" || { echo "[FAIL] $BANTU_EXE missing"; exit 1; }
echo "[PASS] bantu.exe built ($(wc -c <"$BANTU_EXE") bytes)"

# ─── 2. Fresh stage dir ─────────────────────────────────────────────
echo
echo "── [2/5] Staging files ──"
rm -rf "$STAGE"
mkdir -p "$STAGE"

# Application
cp "$BANTU_EXE"            "$STAGE/bantu.exe"
cp "$ROOT/server.b"        "$STAGE/server.b"
cp -r "$ROOT/public"       "$STAGE/public"

# Windows launchers + docs
cp "$ROOT/windows/start.bat"      "$STAGE/"
cp "$ROOT/windows/stop.bat"       "$STAGE/"
cp "$ROOT/windows/reset-db.bat"   "$STAGE/"
cp "$ROOT/windows/README.md"      "$STAGE/"

echo "[PASS] staged app + launchers"

# ─── 3. Runtime DLLs ────────────────────────────────────────────────
echo
echo "── [3/5] Copying runtime DLLs ──"

# SQLite
cp "$WINDEPS/sqlite3.dll" "$STAGE/"
echo "[PASS] sqlite3.dll"

# libcurl + its bundled deps (the curl.se Windows build ships a single
# self-contained libcurl-x64.dll that statically links OpenSSL, nghttp2,
# brotli, etc. — so we only need the one DLL).
cp "$WINDEPS/curl-8.20.0_5-win64-mingw/bin/libcurl-x64.dll" "$STAGE/"
echo "[PASS] libcurl-x64.dll"

# CA bundle (needed for HTTPS requests from libcurl)
cp "$WINDEPS/curl-8.20.0_5-win64-mingw/bin/curl-ca-bundle.crt" "$STAGE/"
echo "[PASS] curl-ca-bundle.crt"

# libc++ runtime (llvm-mingw ships libc++.dll + libunwind.dll + libwinpthread-1.dll)
cp "$MINGW/x86_64-w64-mingw32/bin/libc++.dll"           "$STAGE/"
cp "$MINGW/x86_64-w64-mingw32/bin/libunwind.dll"        "$STAGE/"
cp "$MINGW/x86_64-w64-mingw32/bin/libwinpthread-1.dll"  "$STAGE/"
echo "[PASS] libc++.dll, libunwind.dll, libwinpthread-1.dll"

# ─── 4. Verify everything ───────────────────────────────────────────
echo
echo "── [4/5] Verifying staged files ──"
EXPECTED=(
    bantu.exe
    server.b
    start.bat
    stop.bat
    reset-db.bat
    README.md
    sqlite3.dll
    libcurl-x64.dll
    curl-ca-bundle.crt
    libc++.dll
    libunwind.dll
    libwinpthread-1.dll
)
MISSING=0
for f in "${EXPECTED[@]}"; do
    if [[ ! -f "$STAGE/$f" ]]; then
        echo "[FAIL] missing: $f"
        MISSING=1
    fi
done
[[ "$MISSING" -ne 0 ]] && exit 1
echo "[PASS] all expected files present"

echo
echo "── staged tree ──"
( cd "$STAGE" && find . -maxdepth 2 -printf '%y  %10s  %p\n' | sort )

# ─── 5. Zip it up ───────────────────────────────────────────────────
echo
echo "── [5/5] Zipping ──"
cd "$DIST"
ZIP_NAME="chatbantu-windows-x64.zip"
rm -f "$ZIP_NAME"
zip -r -X "$ZIP_NAME" "chatbantu-windows-x64" > /tmp/zip.log 2>&1 || {
    echo "[FAIL] zip failed"; tail -10 /tmp/zip.log; exit 1
}
echo "[PASS] $DIST/$ZIP_NAME ($(wc -c <"$ZIP_NAME") bytes, $(du -h "$ZIP_NAME" | cut -f1))"
echo
echo "════════════════════════════════════════════════════════════════"
echo "  ✓ Done. Ship this zip:"
echo "      $DIST/$ZIP_NAME"
echo "════════════════════════════════════════════════════════════════"
