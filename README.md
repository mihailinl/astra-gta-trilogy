# Astra in GTA: The Trilogy - The Definitive Edition

**Phase 1: scaffold + DISCOVERY BUILD.** Astra (the Astra companion's 3D avatar) in GTA III, Vice City and San
Andreas - The Definitive Edition, all three on Rockstar's modified UE 4.26 ("Gameface"). This package does not
yet position her correctly in any of the three games: it exists so one supervised run in GTA III tells us how
the game represents its player, before any GTA-specific positioning logic gets written.

## Why a separate integration

astra-reshade's generic Unreal runner (`extern/astra-reshade`, pinned at `v0.2.4`) works with GTA III DE only
partly:

- UE4SS's own pattern scan is ambiguous on GTA III DE's exe and needs per-game signature overrides
  (`game-signatures/README.md`);
- the player controller never possesses a Pawn;
- its view target in gameplay is a far-away default actor;
- UE line traces never hit GTA's own collision (Rockstar's, not Unreal's).

The owner's ruling: no GTA logic in the generic foundation. GTA gets its own integration, the same shape as
[astra-in-death-stranding](https://github.com/mihailinl/astra-in-death-stranding) - built on astra-reshade's
compositor plus a game-specific provider, never editing astra-reshade itself.

## Layout

```
extern/astra-reshade/        submodule, pinned v0.2.4 (e5915eb) - the compositor (astra.addon64), unmodified
AstraGTA/Scripts/main.lua    the provider: a copy of astra-reshade's AstraUE (never edited there) + DISCOVERY MODE
AstraGTA/enabled.txt         UE4SS mod marker (empty)
ue4ss-overlay/Mods/          mods.txt/mods.json: UE4SS's own example mods off, AstraGTA + Keybinds on
manifests/                   one astra-gi-<game>.toml per game (schema 1, astra-game-launcher)
game-signatures/             per-exe UE4SS_Signatures/*.lua overrides - see game-signatures/README.md
tools/
  gi-pack.py                 ported verbatim from astra-reshade/tools/gi-pack.py (schema 1's packer)
  package-gta.sh             builds build/astra-gi-<game>.zip from extern/astra-reshade + the files above
build/                        (gitignored) package output
```

AstraGTA's own header comment says exactly what changed from AstraUE: the identity strings (`[AstraGTA]` in the
log, `astra.gta-trilogy` as the provider id) and a DISCOVERY MODE block. The generic camera/follow/sun logic -
including the Pawn-less fallback and the ground-trace backoff GTA DE already needs - is unchanged, so cutscenes
still show her exactly like any other Unreal game.

## Discovery mode

On by default in this build (`AstraGTA/Scripts/main.lua`, `M.DISCOVERY`). One supervised run in GTA III:

- after ~60 s of **cumulative** gameplay-camera time (FOV in a loose ~70-92 deg horizontal band around GTA's
  ~81 deg - a cutscene is expected to fall outside it; every discovery line logs the fov/axis seen, so the band
  can be re-calibrated from the owner's own log if GTA DE's camera turns out different), calls UE4SS's
  `DumpAllObjects()` **once** - `UE4SS_ObjectDump.txt` lands beside `UE4SS.dll`;
- once: the `GameMode`/`GameState`/`PlayerState` classes;
- every 10 s (bounded cost - never a per-frame scan):
  - the view target's class and full name, and the camera manager's `ViewTarget.Target` /
    `PendingViewTarget.Target`;
  - every live `SkeletalMeshComponent` within 15 m of the camera: its owning actor's class, short name,
    distance, and the mesh asset's name (`FindAllOf("SkeletalMeshComponent")`, one call every 10 s);
  - a count plus the first 5 full names of live actors whose class name contains `Ped`, `Player`, `Vehicle`,
    `Automobile`, `Bike`, `CJ`, `Tommy`, `Claude`, `Camera`, `Pawn` or `Character`
    (`FindAllOf("Actor")`, same 10 s cadence - bounded by frequency, not by scanning fewer objects).

All lines are prefixed `discovery:` in `astra-reshade.log` (grep for it). **The owner runs GTA III** (it needs
his Rockstar login) - this build is not run from here.

## Build

```bash
git submodule update --init --recursive     # extern/astra-reshade + its own extern/minecraft-in-death-stranding
cd extern/astra-reshade && ./build.sh        # -> build/astra.addon64 (needs clang-cl/lld-link/xwin, see its README)
extern/astra-reshade/extern/minecraft-in-death-stranding/tools/fetch_deps.sh   # ReShade 6.8.0 headers+DLL, ReShade.fxh
cd ../..
tools/package-gta.sh                         # -> build/astra-gi-gta3.zip (Vice City/San Andreas SKIP: see below)
```

`tools/package-gta.sh` stages the same tree astra-reshade's own `tools/package-unreal.sh` does (UE4SS, the
add-on, the shaders, licences) from `extern/astra-reshade`'s build output, plus this repo's own `AstraGTA/`,
`ue4ss-overlay/` and `game-signatures/`, then runs `tools/gi-pack.py` (ported, unmodified logic) to fill each
manifest's `@sha256:<path>@` placeholders and check every pinned digest.

## The three games

| game | id | Steam appid | exe | status |
|---|---|---|---|---|
| GTA III DE | `astra.gta-trilogy.gta3` | 1546970 | `Gameface/Binaries/Win64/LibertyCity.exe` | builds (signatures captured) |
| Vice City DE | `astra.gta-trilogy.vicecity` | 1546990 | `Gameface/Binaries/Win64/ViceCity.exe` | **placeholder** - see below |
| San Andreas DE | `astra.gta-trilogy.sanandreas` | 1547000 | `Gameface/Binaries/Win64/SanAndreas.exe` | **placeholder** - see below |

Appids and exe names confirmed via SteamDB (app 1546990, app 1547000) and PCGamingWiki's `Gameface\Binaries\
Win64\{ViceCity,SanAndreas}.exe` layout, 2026-10-20 - neither game was installed on this machine to scan.

**Vice City and San Andreas are placeholders that refuse to build**: their manifests exist (same shape, exe and
appid confirmed) but each needs its own `game-signatures/<Game>-DefinitiveEdition/UE4SS_Signatures/{
StaticConstructObject,ConsoleManager}.lua` - a per-exe byte-pattern override (`game-signatures/README.md`
explains why it must be per-exe) that only exists for GTA III today. `tools/package-gta.sh` detects the missing
files and SKIPS that game's zip with a clear message rather than failing the whole build; `tools/gi-pack.py`
would refuse ("not staged") if asked to pack one anyway. Add the two files, drop the placeholder comment at the
top of that game's manifest, and the package builds - no other change needed.

One important manifest difference from astra-reshade's own GTA III package: **`[target].engine` is omitted**
(commented, with the reason, in every manifest here). `astra-game-launcher`'s only Unreal detection rule
requires the exe name to end `-Win64-Shipping.exe`; none of these three do (Rockstar's own naming), so the
check would always refuse a real install. `exe` + `steam_appid` already fully pin the game, so dropping
`engine` costs no safety - confirmed end-to-end with the launcher CLI (below).

## Validated (2026-10-20)

Built `build/astra-gi-gta3.zip` (36 files, 29 pinned `game_files`, sha256
`67e6a2a73b392943f99f49aa7733bba5399214bf7dc5fe4e5536cb31e3ba3948`) and ran the full `astra-game-launcher` CLI
flow against a scratch fake game layout (`/mnt/data/scratch-ap/gta-trilogy/fake-gta3`, a zero-byte stand-in
`LibertyCity.exe`): `inspect` → `plan` → `install` (29/29 game files) → `launch --dry-run` (prints the Steam
`-applaunch 1546970 --ue4ss-path ... -AstraConfig ...` command) → `uninstall` (all 29 removed, the exe left
alone). Vice City and San Andreas were correctly skipped by `tools/package-gta.sh`.

## Licence

MIT (`LICENSE`). Packages also carry RE-UE4SS (MIT), ReShade (BSD-3-Clause), ReShade.fxh (CC0-1.0) and
astra-reshade/minecraft-in-death-stranding/universal-modder (MIT) unmodified, each with its licence in every
package's `LICENSES/`.
