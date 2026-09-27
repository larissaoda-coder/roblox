#!/usr/bin/env bash
# Verificação completa: formatação, tipos e testes. Uso: ./scripts/check.sh
# Requer rojo, stylua, luau-lsp e lune no PATH (ou em $TOOLS).
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS="${TOOLS:-}"
bin() { if [ -n "$TOOLS" ]; then echo "$TOOLS/$1"; else echo "$1"; fi; }

echo "== Formatação (StyLua)"
"$(bin stylua)" --check src tests

echo "== Tipos (luau-lsp)"
"$(bin rojo)" sourcemap default.project.json -o sourcemap.json >/dev/null
DEFS="${LUAU_DEFS:-globalTypes.d.luau}"
if [ ! -f "$DEFS" ]; then
	curl -sSL -o "$DEFS" https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
fi
OUTPUT="$("$(bin luau-lsp)" analyze --definitions="$DEFS" --sourcemap=sourcemap.json --platform=roblox src 2>&1 || true)"
if echo "$OUTPUT" | grep -q "Error"; then
	echo "$OUTPUT" | grep "Error"
	exit 1
fi

echo "== Testes (Lune)"
"$(bin lune)" run tests/run.luau

echo "== Place"
mkdir -p build
"$(bin lune)" run scripts/export-maps.luau
"$(bin rojo)" build place.project.json -o build/NightShift.rbxlx
for name in Shared Server Client; do
	"$(bin rojo)" build "projects/$name.project.json" -o "build/$name.rbxm"
done
