#!/bin/bash
# Builds this repo's release assets, one per game, from the SAME staged pattern as astra-reshade's own
# tools/package-unreal.sh (reused, not forked - see tools/gi-pack.py's own header):
#   build/astra-gi-gta3.zip        astra-gi-gta3.toml (GTA III DE, exe-pinned) - builds (signatures captured)
#   build/astra-gi-vicecity.zip    astra-gi-vicecity.toml - SKIPPED until ViceCity.exe is scanned
#   build/astra-gi-sanandreas.zip  astra-gi-sanandreas.toml - SKIPPED until SanAndreas.exe is scanned
#
# Sourced from extern/astra-reshade (pinned v0.2.4 - its own build/astra.addon64, shaders/, and its submodule's
# third_party/ cache: ReShade64.dll, ReShade.fxh, the UE4SS zip) plus THIS repo's own AstraGTA/, ue4ss-overlay/
# and game-signatures/. No GTA logic lives in extern/astra-reshade (the owner's ruling) - everything GTA-specific
# is staged from here. tools/gi-pack.py fills each manifest's @sha256:<path>@ placeholders from the staged file
# and checks every pinned digest, refusing a build whose files don't match - same as astra-reshade's own packer.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
RESHADE="$HERE/extern/astra-reshade"
TP="$RESHADE/extern/minecraft-in-death-stranding/third_party"
CACHE="$HERE/build/cache"
# RE-UE4SS's experimental line, mirrored as astra-reshade's own release asset (MIT) - same pin as
# astra-reshade/tools/package-unreal.sh, so both repos' packages ship byte-identical UE4SS.
UE4SS_URL=${UE4SS_URL:-https://github.com/mihailinl/astra-reshade/releases/download/v0.2.1/UE4SS_v3.0.1-1164-g5e627997.zip}
UE4SS_SHA256=3c72142a383e25e9f9553ac9e4d5677aa572e98cb369cac57200efb2e381e603
RESHADE_DLL_SHA256=0cee63f9c9f13f3ac909c5b4903f4dbb4b719a7ab3b4f13b0deaf83c814b94f7

sha() { sha256sum "$1" | cut -d' ' -f1; }
need() { [ -f "$1" ] || { echo "missing $1 ($2)"; exit 1; }; }
need "$RESHADE/build/astra.addon64" "build it: cd extern/astra-reshade && ./build.sh"
need "$TP/reshade-6.8.0-addon/ReShade64.dll" "fetch it: extern/astra-reshade/extern/minecraft-in-death-stranding/tools/fetch_deps.sh"
need "$TP/shaders/ReShade.fxh" "same fetch_deps.sh"
[ "$(sha "$TP/reshade-6.8.0-addon/ReShade64.dll")" = "$RESHADE_DLL_SHA256" ] || { echo "ReShade64.dll is not 6.8.0 Addon's"; exit 1; }

mkdir -p "$CACHE"
zip_file="$CACHE/$(basename "$UE4SS_URL")"
if [ ! -f "$zip_file" ] && [ -f "$RESHADE/build/cache/$(basename "$UE4SS_URL")" ]; then
	cp "$RESHADE/build/cache/$(basename "$UE4SS_URL")" "$zip_file"  # the submodule's own cache already has it
fi
[ -f "$zip_file" ] || curl -fsSL -o "$zip_file" "$UE4SS_URL" || { echo "UE4SS download failed (rotated? set UE4SS_URL to a mirror)"; exit 1; }
[ "$(sha "$zip_file")" = "$UE4SS_SHA256" ] || { echo "UE4SS zip digest mismatch"; exit 1; }

# The staged tree every package shares: UE4SS + the add-on + AstraGTA. Each game's own signature override is
# added on top by pack_game, never here - this function must stay game-agnostic.
stage_common() {
	local out="$1"
	rm -rf "$out"
	mkdir -p "$out/astra-reshade/Shaders" "$out/LICENSES"
	python3 - "$zip_file" "$out" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
for i in z.infolist():
    if i.filename.startswith("/") or ".." in i.filename.split("/") or (i.external_attr >> 16) & 0o170000 == 0o120000:
        sys.exit("unsafe entry in the UE4SS zip: " + i.filename)
z.extractall(sys.argv[2])
PY
	cp -r "$HERE/ue4ss-overlay/." "$out/ue4ss/"
	cp -r "$HERE/AstraGTA" "$out/ue4ss/Mods/AstraGTA"
	cp "$TP/reshade-6.8.0-addon/ReShade64.dll" "$out/dxgi.dll"
	cp "$RESHADE/build/astra.addon64" "$out/astra.addon64"
	cp "$RESHADE/shaders/AstraPassthrough.fx" "$RESHADE/shaders/AstraGame.fxh" "$TP/shaders/ReShade.fxh" "$out/astra-reshade/Shaders/"
	cp "$HERE/LICENSE" "$out/LICENSES/astra-gta-trilogy-MIT.txt"
	cp "$out/ue4ss/LICENSE" "$out/LICENSES/RE-UE4SS-MIT.txt"
	cp "$RESHADE/LICENSE" "$out/LICENSES/astra-reshade-MIT.txt"
	cp "$RESHADE/extern/minecraft-in-death-stranding/LICENSE" "$out/LICENSES/minecraft-in-death-stranding-MIT.txt"
	cp "$RESHADE/extern/minecraft-in-death-stranding/mc/LICENSE.universal-modder" "$out/LICENSES/universal-modder-MIT.txt"
	if [ ! -f "$CACHE/ReShade-LICENSE.md" ]; then
		cp "$RESHADE/build/cache/ReShade-LICENSE.md" "$CACHE/" 2>/dev/null || \
			curl -fsSL -o "$CACHE/ReShade-LICENSE.md" https://raw.githubusercontent.com/crosire/reshade/v6.8.0/LICENSE.md
	fi
	cp "$CACHE/ReShade-LICENSE.md" "$out/LICENSES/ReShade-BSD-3-Clause.md"
}

# $1: integration id (matches manifests/astra-gi-<id>.toml); $2: game-signatures/<dir>. A game whose signature
# overrides are not yet captured (Vice City, San Andreas - game-signatures/README.md) is SKIPPED, not failed:
# the placeholder manifest stays in the repo, but no zip is produced until its two .lua files exist.
pack_game() {
	local id="$1" sigdir="$2"
	local manifest="$HERE/manifests/astra-gi-$id.toml"
	local sigsrc="$HERE/game-signatures/$sigdir/UE4SS_Signatures"
	if [ ! -f "$sigsrc/StaticConstructObject.lua" ] || [ ! -f "$sigsrc/ConsoleManager.lua" ]; then
		echo "build/astra-gi-$id.zip: SKIPPED - no UE4SS signature overrides yet for $sigdir (game-signatures/README.md)"
		return 0
	fi
	local out="$HERE/build/astra-gi-$id"
	stage_common "$out"
	mkdir -p "$out/game-signatures/$sigdir/UE4SS_Signatures"
	cp "$sigsrc/"*.lua "$out/game-signatures/$sigdir/UE4SS_Signatures/"
	rm -f "$HERE/build/astra-gi-$id.zip"
	python3 "$HERE/tools/gi-pack.py" "$manifest" "$out" "$HERE/build/astra-gi-$id.zip"
}

pack_game gta3 GTA3-DefinitiveEdition
pack_game vicecity ViceCity-DefinitiveEdition
pack_game sanandreas SanAndreas-DefinitiveEdition
