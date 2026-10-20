# Per-game UE4SS signature overrides

UE4SS's built-in pattern scan finds the engine's core addresses (`GUObjectArray`, `GMalloc`,
`StaticConstructObject_Internal`, `ConsoleManagerSingleton`, ...) automatically in almost every Unreal game.
When a game's compiler/build settings make the built-in pattern ambiguous, a `UE4SS_Signatures/<Symbol>.lua`
file can override the scan for just that symbol
(<https://docs.ue4ss.com/guides/fixing-compatibility-problems.html>,
<https://docs.ue4ss.com/dev/custom-game-configs.html>).

**These files were moved here, verbatim, from astra-reshade** (`runners/unreal/game-signatures/
GTA3-DefinitiveEdition/`) when GTA got its own integration (the owner's ruling: no GTA logic in the generic
foundation - see `../README.md`). The evidence and exact AOBs are unchanged from the originals; this repo now
owns the files and their manifest wiring.

## Why a per-game override replaces the scan outright (and must stay exe-pinned)

A `UE4SS_Signatures/<Symbol>.lua` file does not *add* a candidate alongside UE4SS's own scan - it **replaces**
that scan outright (`UE4SS/src/Signatures.cpp::setup_lua_scan_overrides`, RE-UE4SS experimental
3.0.1-1164-g5e627997): the override activates the instant the file **exists**, regardless of what its
`Register()`/`OnMatchFound()` do at runtime. If the AOB then finds nothing in *that* game's exe, UE4SS does
**not** fall back to its built-in scan - it records a scan failure for that symbol, and losing
`StaticConstructObject_Internal` or `GUObjectHashTables` is fatal to UE4SS ("Fatal Error: PS scan timed out",
the exact failure GTA III DE hit before this override existed).

So each override must only ever reach its OWN game's exe - never a shared "every Unreal game" tree. Each
manifest in `../manifests/` pins an exact `[target].exe` and `steam_appid`, so `astra-game-launcher`
(`src/plan.rs::plan_install`) refuses to install (or run) one on any other game, `GAME_MISMATCH`, exactly like a
mismatched Steam appid. That pin is what makes shipping an exe-specific byte pattern safe with no launcher
change.

## GTA III - The Definitive Edition (captured)

`GTA3-DefinitiveEdition/UE4SS_Signatures/`:

- `StaticConstructObject.lua` - resolves the ambiguity between the old multi-argument overload
  (`0x140C89270`) and the canonical `StaticConstructObject_Internal(const FStaticConstructObjectParameters&)`
  (`0x141A2B330`, the one UE4SS wants).
- `ConsoleManager.lua` - resolves the ambiguity between the real `ConsoleManagerSingleton` lazy initializer
  (`0x1416EB630`, confirmed by its own call into **GMalloc at the exact address UE4SS.log already reports**,
  `0x14540F8D0`) and a different per-cvar accessor function that merely calls into it (`0x1426853B0`).

Both AOBs were verified to match **exactly once** across the whole `LibertyCity.exe` image, at exactly the
address each file names. Full evidence is in each file's own header comment (unchanged from the astra-reshade
original).

## Vice City / San Andreas - NOT CAPTURED

`ViceCity-DefinitiveEdition/` and `SanAndreas-DefinitiveEdition/` do not exist yet: `ViceCity.exe` and
`SanAndreas.exe` were not available to scan on this machine. All three Definitive Edition titles share
"Gameface" (modified UE 4.26), so their binaries may well share GTA III's exact call sites and byte patterns -
but that is a guess, not evidence, and `manifests/astra-gi-vicecity.toml` / `astra-gi-sanandreas.toml` stay
placeholders (`tools/package-gta.sh` refuses to package them, "not staged") until someone actually scans those
two exes and proves it (or disproves it: a differently-compiled DLC/game-specific class layout would move
these offsets).

To add a game's signatures once scanned: create `<Game>-DefinitiveEdition/UE4SS_Signatures/{StaticConstructObject,
ConsoleManager}.lua` here (or whichever symbols the scan needs), following the AOB-evidence shape of GTA III's
files, then remove that game's manifest's placeholder header comment - the `[[game_files]]` entries already
point at the right paths.
