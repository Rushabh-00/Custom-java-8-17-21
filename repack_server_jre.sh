#!/bin/bash
set -euo pipefail

JAVA_VERSION=$1
FULL_JRE_DIR=$2
REPACKED_DIR=$3

rm -rf "$REPACKED_DIR"
cp -a "$FULL_JRE_DIR" "$REPACKED_DIR"
cd "$REPACKED_DIR"

find . -type f \( -perm -u+x -o -name "*.so" -o -name "*.so.*" \) -exec file {} \; | grep ELF | cut -d: -f1 | while read -r bin; do
  strip --strip-unneeded "$bin" || true
done

rm -rf demo sample man docs include lib/missioncontrol lib/visualvm lib/javafx
find lib -name "*.a" -type f -delete
find lib -name "*.diz" -type f -delete
find . -type f \( -name "*.pdb" -o -name "*.exe" -o -name "*.dll" -o -name "*.lib" \) -delete
rm -rf src.zip
rm -rf lib/javafx*
rm -rf share/man

chmod -R u+rwX,go+rX,go-w .
