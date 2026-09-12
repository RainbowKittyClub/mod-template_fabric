# fabric_mod_skeleton

Generic starting point for a server-side Fabric mod targeting Minecraft 26.2. Fabric API is a hard
dependency; Polymer (virtual entities, blocks, resource pack) is wired up as a *soft* dependency
(see "Polymer: client-optional content" below) and bil (blockbench-import-library) is a hard one —
drop the ones you don't need. `rkc/STYLE.md` covers everything shared across mods: Java style,
linting, datagen, the dev-server lifecycle.

This repo is split across three branches, none of them meant to be cloned except `main`:

- **`main`** (this branch) — this file and `setup.sh`. What a plain `git clone` gets you.
- **`template`** — the actual example source and docs (`src/`, `docs/`, `README.template.md`).
  `setup.sh` pulls it in.
- **`gradle`** — `build.gradle`, `settings.gradle`, `gradle.properties.template`, the wrapper and
  `devserver.gradle`: generic enough to be identical across every mod, so it's a submodule instead
  of duplicated per mod. `setup.sh` symlinks most of it into place.

## Turning this into a new mod

```
git clone fabric_mod_skeleton rkc/mods/<name>   # run from the minecraft-dev workspace root
cd rkc/mods/<name>
./setup.sh
```

`setup.sh` does the following, then deletes itself:

1. Fetches the `template` branch and checks its files into the working tree.
2. `rm -rf .git && git init` — detaches from the template's own history; every first-party mod is
   its own independent repo (see the workspace `CLAUDE.md`), not a fork of this one.
3. `git submodule add -b gradle <this repo> gradle`.
4. Symlinks `gradlew`, `gradlew.bat`, `build.gradle` and `settings.gradle` from the submodule into
   the root — Gradle's CLI only looks for these in the current directory, but they're still versioned
   in exactly one place (the `gradle` branch), not forked into every mod that uses this template.
5. Copies `gradle/gradle.properties.template` to `gradle.properties` — this one **is** copied, not
   symlinked, since it's real per-mod state (`mod_id`, `mod_name`, ...), not shared boilerplate.
6. `git config core.hooksPath ../../../scripts/githooks` — re-points at the workspace-shared hooks,
   since `git init` doesn't inherit this.
7. `mv README.template.md README.md` — replaces this file with the new mod's own (currently blank)
   README.

## Renaming the placeholders

Every project-specific string is the literal placeholder `CHANGEME`, or lowercase `changeme` where
a lowercase identifier is required (`mod_id`, package segments, the mixins json filename). Find and
replace across the whole tree, including filenames — exclude `.git` and the `gradle` submodule
(nothing in it needs renaming; `settings.gradle`'s `rootProject.name` already derives itself from
`gradle.properties`'s `mod_id` at build time):

```
grep -rl CHANGEME . --exclude-dir={.git,gradle}
grep -rl changeme . --exclude-dir={.git,gradle}
```

At minimum, rename:

- `gradle.properties` — `mod_name`, `mod_description`, `mod_authors`, `mod_website`, `mod_issues`, `mod_license`, `maven_group`, `mod_id`, `entrypoint`
- `src/main/java/club/rainbowkitty/changeme/CHANGEME.java` — move to match the new package/class name, update `MOD_ID`
- `src/main/resources/changeme.mixins.json` — rename the file, update `package`, update the reference in `fabric.mod.json`'s `mixins` array
- `src/datagen/java/club/rainbowkitty/changeme/datagen/CHANGEMEDataGenerator.java` — move to match the new package/class name, update the `fabric-datagen` entry in `fabric.mod.json`

Mod ids are conventionally one lowercase word (`rktweaks`, `companions`); the directory may be
hyphenated, and the package always drops separators. Then fill in `README.md` (already swapped in
from `README.template.md` by `setup.sh`): what the mod does and how to install it. Build specifics go
in `docs/BUILDING.md`; feature plan docs go under `docs/plan/` (see `PLANNING.md`).

## Polymer: client-optional content

The template ships one worked example — a block, `changeme:example_block` — of serving *real*
content (correct hitbox, real registry id, the mod's own models) to clients that run this mod, and a
Polymer substitute to everyone else, decided **per connection** from Polymer's networking handshake:

| Client | Sees | Resource pack |
| --- | --- | --- |
| Runs this mod (+ polymer-core) client-side | the real `example_block`, exact hitbox | not needed; may decline |
| Vanilla / Polymer-only, accepts the pack | a note-block pool state retextured to the custom model | declinable — never required |
| Vanilla / Polymer-only, declines the pack | the bare note block (full cube, right shape) | — |
| Connects to a server with **no Polymer** | nothing custom, unless it also runs this mod | — |

**How it's wired:**

- `fabric.mod.json` puts `polymer-*` in `suggests`, not `depends` — the jar loads on a server with no
  Polymer at all. `bil` stays a hard dependency; drop it too if the mod needs neither.
- `content/ExampleBlock` is a plain `Block`, no Polymer imports — real shape and behaviour, shared
  `register*`/`*Settings` helpers used by both paths.
- `polymer/PolymerExampleBlock extends ExampleBlock implements PolymerTexturedBlock,
  PolymerClientDecoded`, instantiated only when polymer-core is present. `getPolymerBlockState`
  returns the real state for a `PolymerAware` client, else a `polymer-blocks` pool state.
- `polymer/PolymerAware` registers a no-payload handshake packet id; `has(...)` reports whether a
  given connection's client also loaded this mod.
- `polymer/PolymerIntegration` is the only class `CHANGEME` touches behind
  `FabricLoader.isModLoaded("polymer-core")` — requests the pool state, registers the Polymer block +
  a `PolymerBlockItem` fallback, calls `PolymerResourcePackUtils.addModAssets("changeme")`.
- `assets/changeme/` + `data/changeme/` are the block's models, blockstate, item model, loot table,
  `mineable/pickaxe` tag and lang, hand-authored (26.2's vanilla model generators are almost all
  private). `addModAssets` copies `assets/changeme/` into Polymer's generated pack for clients that
  accept it.

`addModAssets` puts the models in the pack; it does **not** push or require it (`markAsRequired()` is
deliberately not called) — that's the server's `polymer-autohost` config
(`config/polymer/auto-host.json`, `required`/`mod_override`), not this mod's call. A client that
declines just sees the fallback block.

Delete `content/`, `polymer/`, the `CHANGEME` branch and the `example_block` assets/data once you have
your own content. To keep the pattern for an **item**, mirror it with `PolymerItem`/`PolymerBlockItem`
(or `PolymerItem.registerOverlay` to avoid subclassing); for an **entity**, with
`PolymerEntity.getPolymerEntityType` + `canSynchronizeToPolymerClient`. An item or entity with no
close vanilla lookalike is a poor fit for this pattern — say so in the mod's README.

## Dev-server defaults

`gradle/devserver.gradle` (pulled in by `build.gradle`'s `apply from:`) seeds `run/` and `run-quilt/`
the first time `runServer` runs, so the server comes up instead of stopping on the unaccepted EULA. It
is merge-if-absent — a hand edit sticks; `rm -rf run/` resets to these:

- `run/eula.txt` → `eula=true`.
- `run/server.properties` — `online-mode=false`, `gamemode=creative`, a superflat `minecraft:flat`
  world, all three 26.2 experiment datapacks in `initial-enabled-packs`, `pause-when-empty-seconds=0`,
  `max-tick-time=-1` (no watchdog), `spawn-protection=0`, rcon open. Ports, rcon password and the
  datapack pack format are the `dev_*` keys in `gradle.properties`.
- `run/ops.json` — `Kalic0` and `LuckySkips` at level 4, offline-mode UUIDs (edit the `devServerOps`
  list in `gradle/devserver.gradle` to change it).
- `run/world/datapacks/zz_dev_defaults/` — a one-shot `#load` function (guarded by a storage flag, so
  the rules stay editable) that forces `command_blocks_work` on and turns off `advance_time`,
  `block_drops` and all `spawn_*` rules.

`dev_server_port`/`dev_rcon_port` carry template defaults — give a mod that runs its dev server next
to another its own values, outside 25565–25567 (Docker publishes that range). World settings only bind
at world creation, so change them *before* the first `runServer` or delete `run/world/`.

`runClient` uses its own `run/client`, not `run/` — the client and `runServer` both regenerate
`polymer/resource_pack.zip` on start, and sharing a dir means whichever finishes last silently
desyncs the other's advertised hash. `run/client/mods` is a symlink to `run/mods` so the client sees
the same third-party mods as the dev server without duplicating jars.

## Quilt dev server

`gradle/devserver.gradle` also adds `runQuiltServer`/`stopQuiltServer`, reusing the same dev workspace
under `run-quilt/` with Quilt's Knot entrypoint and `quilt-loader` swapped in for `fabric-loader`. The
`quilt_*` keys in `gradle.properties` pin the loader and its runtime libs by hand (they live in the
loader's installer manifest, not maven metadata).

**Partly working on 26.2, as of the last check:** it *boots* — Quilt Loader starts a MC 26.2 server,
RCON and the seeded world come up — but does **not load this mod, Fabric API, or Polymer**. Loom
splits the mod across `build/classes/java/main` + `build/resources/main` and rejoins them via the
`fabric.classPathGroups` system property, which Fabric Loader reads in dev and Quilt's Knot does not.
So today it smoke-tests *vanilla under Quilt*, not *this mod under Quilt* — open work, and Quilt has no
stable 26.2 release yet. Delete the QuiltMC repo, the `quiltLoader` configuration, the
`loom { runs { … } }` block and the two Quilt tasks from `gradle/devserver.gradle`, plus the `quilt_*`
properties from `gradle.properties`, if the mod will never be tested under Quilt.

## Bil version pin

`gradle.properties` pins `bil_version=2.1.3+26.2` from `mavenLocal()`. bil is distributed on
[CurseForge](https://www.curseforge.com/minecraft/mc-mods/blockbench-import-library), which is not a
maven, and `maven.tomalbrc.de` carries nothing past `1.1.13+1.21` — so there's no 26.x coordinate to
resolve and the pin has to come from a local build. Build `blockbench-import-library` from source into
`mavenLocal` first, or drop the Polymer/bil dependencies entirely if the new mod doesn't need animated
virtual-entity models.
