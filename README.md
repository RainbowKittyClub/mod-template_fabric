# fabric_mod_skeleton

Generic starting point for a server-side Fabric mod targeting Minecraft 26.2. Fabric API is a hard
dependency; Polymer (virtual entities, blocks, resource pack) is wired up as a *soft* dependency
(see "Polymer: client-optional content" below) and bil (blockbench-import-library) is a hard one —
drop the ones you don't need, along with `mavenLocal()`, the Modrinth/Sponge repos and the
`bil_version` pin if bil goes.

`rkc/STYLE.md` covers everything shared across mods: Java style, the build, linting, datagen and the
dev-server lifecycle. This file covers only what is specific to standing a new mod up from this
template.

## Using this template

Clone this repo into `rkc/mods/<name>`, then detach it from the template's own history — every
first-party mod is its own independent repo (see the workspace `CLAUDE.md`), not a fork of this one:

```
git clone fabric_mod_skeleton rkc/mods/<name>   # run from the minecraft-dev workspace root
cd rkc/mods/<name>
rm -rf .git && git init
git config core.hooksPath ../../../scripts/githooks   # re-point at the workspace-shared hooks; git init doesn't inherit this
```

Mod ids are conventionally one lowercase word (`rktweaks`, `companions`); the directory may be
hyphenated, and the package always drops separators.

Every project-specific string is the literal placeholder `CHANGEME`, or lowercase `changeme` where a
lowercase identifier is required (`mod_id`, package segments, the mixins json filename). Find and
replace across the whole tree, including filenames — a fresh clone carries no build output, so the
only exclude needed is `.git` itself:

```
grep -rl CHANGEME . --exclude-dir=.git
grep -rl changeme . --exclude-dir=.git
```

At minimum, rename:

- `gradle.properties` — `mod_name`, `mod_description`, `mod_authors`, `mod_website`, `mod_issues`, `mod_license`, `maven_group`, `mod_id`, `entrypoint`
- `settings.gradle` — `rootProject.name`
- `src/main/java/club/rainbowkitty/changeme/CHANGEME.java` — move to match the new package/class name, update `MOD_ID`
- `src/main/resources/changeme.mixins.json` — rename the file, update `package`, update the reference in `fabric.mod.json`'s `mixins` array
- `src/datagen/java/club/rainbowkitty/changeme/datagen/CHANGEMEDataGenerator.java` — move to match the new package/class name, update the `fabric-datagen` entry in `fabric.mod.json`

Then replace this file: delete it and rename `README.template.md` to `README.md`. That template is
the new mod's own README — what the mod does and how to install it. Build specifics go in
`docs/BUILDING.md` (carried along with the clone); feature plan docs go under `docs/plan/` (see
`PLANNING.md`).

## Polymer: client-optional content

The template ships one worked example — a block, `changeme:example_block` — of serving *real*
content (correct hitbox, real registry id, the mod's own models) to clients that run this mod, and
a Polymer substitute to everyone else, decided **per connection** from Polymer's networking
handshake. What each client sees:

| Client | Sees | Resource pack |
| --- | --- | --- |
| Runs this mod (+ polymer-core) client-side | the real `example_block`, exact hitbox | not needed; may decline |
| Vanilla / Polymer-only, accepts the pack | a note-block pool state retextured to the custom model | declinable — never required |
| Vanilla / Polymer-only, declines the pack | the bare note block (full cube, right shape) | — |
| Connects to a server with **no Polymer** | nothing custom, unless it also runs this mod | — |

### How it's wired

- **`fabric.mod.json`** — `polymer-*` are in `suggests`, not `depends`. The jar loads on a server
  with no Polymer at all (real content only). `bil` stays a hard dependency; drop it too if the mod
  needs neither.
- **`content/ExampleBlock`** — a plain `Block`, no Polymer imports. Real shape and behaviour live
  here. Its shared `register*` / `*Settings` helpers are used by both paths.
- **`polymer/PolymerExampleBlock`** — `extends ExampleBlock implements PolymerTexturedBlock,
  PolymerClientDecoded`. Instantiated only when polymer-core is present. `getPolymerBlockState`
  returns the real state for a `PolymerAware` client, else a `polymer-blocks` pool state.
- **`polymer/PolymerAware`** — registers a no-payload handshake packet id; `has(...)` reports
  whether a given connection's client also loaded this mod.
- **`polymer/PolymerIntegration`** — the only class `CHANGEME` touches behind
  `FabricLoader.isModLoaded("polymer-core")`. Requests the pool state, registers the Polymer block +
  a `PolymerBlockItem` fallback, and calls `PolymerResourcePackUtils.addModAssets("changeme")`.
- **`assets/changeme/` + `data/changeme/`** — the block's models, blockstate, item model, loot
  table, `mineable/pickaxe` tag and lang, hand-authored (26.2's vanilla model generators are almost
  all private; hand JSON is what the first-party mods do). `addModAssets` copies `assets/changeme/`
  into Polymer's generated pack for clients that accept it.

### `markAsRequired()` is deliberately not called

`addModAssets` puts the models in the pack; it does **not** push or require it. Whether the pack is
delivered and whether it's required is the server's `polymer-autohost` config
(`config/polymer/auto-host.json` on a live server — `required`, `mod_override`), not this mod's
call. A client that declines simply sees the fallback block. Note polymer-autohost has no
per-client "skip" hook, so a client running this mod is still *offered* the (declinable) pack it
doesn't need — cosmetic only.

### Adapting or removing it

Delete `content/`, `polymer/`, the `CHANGEME` branch and the `example_block` assets/data once you
have your own content. To keep the pattern for an **item**, mirror it with `PolymerItem` /
`PolymerBlockItem` (or `PolymerItem.registerOverlay` to avoid subclassing); for an **entity**, with
`PolymerEntity.getPolymerEntityType` + `canSynchronizeToPolymerClient`. An item or entity with no
close vanilla lookalike is a poor fit for this pattern — say so in the mod's README.

## Dev-server defaults

The dev-server wiring lives in `gradle/devserver.gradle` (pulled in by an `apply from:` line in
`build.gradle`) — it is generic across mods and reads only `gradle.properties`.

`runServer` depends on `configureRunServer`, which seeds `run/` (and `run-quilt/`) the first time so
the server actually comes up instead of stopping on the unaccepted EULA. It is merge-if-absent —
every value below can be hand-edited afterwards and the edit sticks; `rm -rf run/` resets to these.

- `run/eula.txt` → `eula=true`.
- `run/server.properties` — `online-mode=false`, `gamemode=creative`, a superflat `minecraft:flat`
  world (bedrock + 10 layers of smooth stone, plains biome), all three 26.2 experiment datapacks
  (`minecart_improvements`, `redstone_experiments`, `trade_rebalance`) in `initial-enabled-packs`,
  `pause-when-empty-seconds=0`, `max-tick-time=-1` (no watchdog),
  `spawn-protection=0`, rcon open, game port. Ports, rcon password and the datapack pack format are
  the `dev_*` keys in `gradle.properties`.
- `run/ops.json` — `Kalic0` and `LuckySkips` at level 4, with offline-mode UUIDs (edit the
  `devServerOps` list in `gradle/devserver.gradle` to change it; UUIDs are recomputed).
- `run/world/datapacks/zz_dev_defaults/` — a one-shot `#load` function (guarded by a storage flag,
  so the rules stay editable) that forces `command_blocks_work` on and turns off `advance_time`,
  `block_drops` and all `spawn_*` rules.

`dev_server_port` / `dev_rcon_port` carry template defaults — give a mod that runs its dev server next
to another its own values in `gradle.properties`, outside 25565–25567 (Docker publishes that range).
The world settings and `initial-enabled-packs` only bind at world creation, so change them *before*
the first `runServer` or delete `run/world/`. Delete the "Dev-server defaults" section of `gradle/devserver.gradle` (and
the `dependsOn 'configureRunServer'` lines) if a mod wants Loom's bare `run/` instead.

## Client dev run

`runClient` uses its own `run/client`, not `run/` — the client and `runServer` both regenerate
`polymer/resource_pack.zip` on start, and sharing a dir means whichever finishes last silently
desyncs the other's advertised hash. `run/client/mods` is a symlink to `run/mods` (kept in place by
`configureRunClient`, which `runClient` depends on) so the client sees the same third-party mods as
the dev server without duplicating jars.

## Quilt dev server

`gradle/devserver.gradle` adds `runQuiltServer` / `stopQuiltServer` alongside Loom's `runServer` /
`stopServer`. It reuses the same dev workspace under its own `run-quilt/`, but with Quilt's Knot
entrypoint and `quilt-loader` swapped in for `fabric-loader` on the run classpath. The `quilt_*` keys
in `gradle.properties` pin the loader and its runtime libs (carried by hand — they live in the
loader's installer manifest, not maven metadata, so refresh them whenever `quilt_loader_version`
moves); the `quiltLoader` configuration keeps them off every other classpath.

**Partly working on 26.2, as of the last check:** `runQuiltServer` *boots* — Quilt Loader 0.31.0-beta.4
starts a MC 26.2 server, RCON and the seeded world come up. But it does **not load this mod, Fabric
API, or Polymer**. Loom's Fabric run splits the mod across `build/classes/java/main` +
`build/resources/main` and rejoins them via the `fabric.classPathGroups` system property, which
Fabric Loader reads in dev and Quilt's Knot does not; there's also no quilted-fabric-loader on the
classpath to pick up Fabric mods. So today it smoke-tests *vanilla under Quilt*, not *this mod under
Quilt*. Making it load the mod needs a `fabric.classPathGroups` equivalent for Knot and a QFL build —
open work, and Quilt has no stable 26.2 release yet. See the comment on the task in
`gradle/devserver.gradle`.

Delete the QuiltMC repo, the `quiltLoader` configuration and its dependencies, the
`loom { runs { … } }` block and the two Quilt tasks from `gradle/devserver.gradle`, plus the
`quilt_*` properties from `gradle.properties`, if the mod will never be tested under Quilt.

## Bil version pin

`gradle.properties` pins `bil_version=2.1.3+26.2` from `mavenLocal()`. bil is distributed on
[CurseForge](https://www.curseforge.com/minecraft/mc-mods/blockbench-import-library), which is not a
maven, and `maven.tomalbrc.de` carries nothing past `1.1.13+1.21` — so there is no 26.x coordinate
to resolve and the pin has to come from a local build.

Build `blockbench-import-library` from source into `mavenLocal` first, or drop the Polymer/bil
dependencies entirely if the new mod doesn't need animated virtual-entity models.
