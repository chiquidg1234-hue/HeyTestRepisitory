#!/bin/bash
# Recolector de evidencia de mantenimiento de un repositorio de GitHub.
# Uso:  ./probe.sh owner/repo
#       xargs -P 8 -I{} ./probe.sh {} < repositorios-evaluados.txt
#
# No ejecuta nada del repositorio: solo clona metadatos (sin blobs) y lee el historial.
set -u
R="$1"
D="$(mktemp -d)"
if ! timeout 120 git clone -q --depth 100 --filter=blob:none --no-checkout "https://github.com/$R" "$D" 2>/dev/null; then
  echo "$R|CLONE_FAILED"; rm -rf "$D"; exit 0
fi
BR=$(git -C "$D" symbolic-ref --short HEAD 2>/dev/null)
HEAD_DATE=$(git -C "$D" log -1 --format=%cI 2>/dev/null)
NOW=$(date +%s); HD=$(git -C "$D" log -1 --format=%ct 2>/dev/null)
DAYS=$(( (NOW - HD) / 86400 ))
C30=$(git -C "$D" log --since="30 days ago"  --oneline 2>/dev/null | wc -l)
C90=$(git -C "$D" log --since="90 days ago"  --oneline 2>/dev/null | wc -l)
C365=$(git -C "$D" log --since="365 days ago" --oneline 2>/dev/null | wc -l)
AUTH=$(git -C "$D" log --format='%ae' 2>/dev/null | sort -u | wc -l)
NCOM=$(git -C "$D" log --oneline 2>/dev/null | wc -l)
TREE=$(git -C "$D" ls-tree -r --name-only HEAD 2>/dev/null)
echo "$R|branch=$BR|head=$HEAD_DATE|days_since=$DAYS|commits_30d=$C30|commits_90d=$C90|commits_365d=$C365|distinct_authors_last${NCOM}=$AUTH|files=$(echo "$TREE" | wc -l)|license_file=$(echo "$TREE" | grep -icE '^(LICENSE|COPYING)')|ci_workflows=$(echo "$TREE" | grep -cE '^\.github/workflows/')|test_files=$(echo "$TREE" | grep -icE '(^|/)(tests?|spec|__tests__)/')|security_md=$(echo "$TREE" | grep -icE '^(SECURITY\.md|\.github/SECURITY\.md)')"
rm -rf "$D"
