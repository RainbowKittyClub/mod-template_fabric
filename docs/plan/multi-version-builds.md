# Multi-version builds with Stonecutter

Let any first-party mod build for several Minecraft versions (26.2 and 26.3 first) from one source
tree, through Stonecutter in this shared build. A mod opts in from its `gradle.properties`, and a mod
that doesn't opt in builds exactly as before.

Verified by a spike on 2026-10-19:
- **Setup:** a scratch mod (`/tmp/claude-1000/sc-spike`) symlinking this branch the way real mods
  symlink the submodule, and a copy without the opt-in keys as the single-version regression.
- **Proved there:** Stonecutter 0.9.8 with this build's Groovy scripts, Gradle 9.5.1 and Loom
  1.17.19; one tree building `+26.2` and `+26.3` jars, each with its own code and `fabric.mod.json`;
  active-version switching; a 26.3 dev server booting and stopping from its version node.
- **Not yet tried on a real mod:** datagen, the kalic0re shaded jar, and Polymer 0.18 on 26.3.

**Stage order.**
- S1 (the spike) is done.
- S2 (opt-in and paths) and S3 (`devserver.sh`) need only S1. S4 (lint) and S5 (scaffold and docs)
  need S2.
- S6 (kalic0re for both versions) needs S2. S7 (first real mod, polymer-diagonal-walls) needs S2–S6.
- S8 (datagen mods) needs S7. S9 (an `rkc/26.3` Polymer fork build) is independent and only
  matters once a 26.3 server runs fork-only fixes.
- The feature is usable for code-only mods after S7, and complete after S8.

---

## Findings that reshape the work

**The Polymer fork keeps one branch per version; only first-party mods use Stonecutter.** Upstream
Polymer branches per Minecraft version (`dev/26.1`, `dev/26.2`, `dev/26.3`) and takes PRs per
branch. `dev/26.3` is the 26.2 tag plus 12 commits over 80 files, so a Stonecutter fork would need
those as hand-written conditionals, redone on every upstream update. The fork keeps `-26.3` twins
instead, made with `scripts/fork-twin.sh`.

**Plain Stonecutter, not Stonecraft.** Stonecraft wraps Stonecutter with Architectury for
multi-loader builds. Polymer makes NeoForge moot, and the README doesn't say anything about
single-loader projects.

**Each mod needs its own controller file.** Stonecutter rewrites the `stonecutter.active` line of
the root build file when the active version changes. Symlinked from here, one switch would flip every
mod. So `stonecutter.gradle` is a real per-mod file, like `gradle.properties`.

**Version nodes resolve project-relative paths under `versions/<v>/`.** Files shared by every
version must use `rootProject.file(...)`: the class tweaker, `gradle/devserver.gradle`,
`build.mod.gradle`, `LICENSE`, and `src/` for the stray-`.claude` sweep. Loom keeps a node's cache at
`<root>/.gradle/loom-cache/projects/<v>/`, which `stopServer` needs to find its server. Per-version
state (`run/`, `build/`) correctly stays under the node.

**Inactive code is a `/* */` block, which the house lint rejects.** In the spike,
`RegexpSinglelineJava` ("Use // for inline comments") flagged the commented-out 26.3 branch.

**Polymer on 26.3 is 0.18.x** (0.18.4 newest on Maven), a minor-version API bump beyond the game
version. The RKC fork's 26.3 base is `2b8b908d`.

## How these stages get tested

- **Scratch mods.** The `sc-spike` scratch mod covers the template mechanics; its `sc-plain` copy
  without the opt-in keys covers mods that stay single-version.
- **Real mods.** From S6 on, each converted mod must also:
  - build `./gradlew build` into `versions/<v>/build/libs/<id>-<ver>+<mc>.jar` for every version;
  - boot a dev server per version with no `Mixin apply failed`;
  - pass its existing bot legs or in-world checks on 26.2.
- **Live server.** Nothing deploys from this work until a mod's own plan says so.

A stage isn't finished until its "Done when" is observed, so a failure at stage N implicates stage N
and not the ones before it.

## S1 — Spike — **done**

**Build.** Branch `gradle-stonecutter` off `gradle` `4dcbbaf`, and the scratch mod described above.

**Done when.** Both jars build from one tree with their own code, switching works both ways, a 26.3
dev server boots and stops, and the plain copy still builds a single jar with no subprojects.

### As built

All observed on 2026-10-19:
- `scspike-0.1.0+26.2.jar` logs "built for 26.2"; `+26.3` logs "built for 26.3" and declares
  `"minecraft": "26.3"`.
- `./gradlew "Set active project to 26.3"` rewrote the source and the controller line, and
  `"Reset active project"` restored both.
- `:26.3:runServer` booted 26.3 in about 10 s on the node's own ports (25794/25796).
- `:26.3:stopServer` ended it, once its launch-config path was fixed.
- Stonecutter warns once about Groovy build scripts; `dev.kikugie.stonecutter.hard_mode=true`
  acknowledges it.

## S2 — Opt-in and shared paths — **done**

**Build.**

- **`settings.gradle`:** with `stonecutter_versions` present, put `dev.kikugie:stonecutter` on the
  settings classpath (version `stonecutter_version`), apply it, and create the root tree from
  `stonecutter_versions` with `vcsVersion = stonecutter_vcs_version`. A settings `plugins {}` block
  can't be conditional, hence the buildscript classpath.
- **`build.gradle`:**
  - use `rootProject.file` for every shared path in the finding above;
  - version the jar `<mod_version>+<minecraft_version>` under Stonecutter;
  - compute `loomLaunchConfig` once for `stopServer` and `devserver.gradle`.
- **Per-version properties:** each `versions/<v>/gradle.properties` holds the version's keys:
  `minecraft_version`, `fabric_version`, `polymer_version`, dev ports and the like. Gradle hands
  them to that node, so `project.<key>` reads stay as they are.
- **Per-mod controller:** `stonecutter.gradle`, holding
  `plugins { id 'dev.kikugie.stonecutter' }` and `stonecutter.active '<v>' /* [SC] DO NOT EDIT */`.

**Done when.** The spike checks pass again on the committed branch. Then one real single-version
mod (better-barriers) builds byte-identical jars before and after its submodule points at this
branch.

### As built

Commit `537eaec`, checked on 2026-10-19:
- The spike rebuilt `+26.2` and `+26.3` jars from the committed branch.
- Two scratch copies of better-barriers (shaded kalic0re, dev server) were built:
  - one on `gradle` `4dcbbaf`, its submodule's commit;
  - one on this branch.
- Their `betterbarriers-0.1.1.jar` files match entry for entry (68 entries, none differing) and keep
  the unsuffixed name.

## S3 — `devserver.sh` per version — **done**

**Build.** Add `--mc <v>` to `scripts/devserver.sh`:
- run directory `versions/<v>/run`;
- launch marker `<root>/.gradle/loom-cache/projects/<v>/launch.cfg`;
- tasks `:<v>:runServer` and `:<v>:stopServer`.

Without `--mc`, a Stonecutter mod uses its `stonecutter_vcs_version`, and a plain mod is unchanged.

**Done when.** `start`, `rcon`, `logs`, `mixins` and `stop` work for both versions of the spike, and
for one plain mod.

### As built

- **`scripts/devserver.sh`** (workspace, not a repo) takes `--mc <v>` right after the mod
  directory. A mod counts as Stonecutter when it has `stonecutter.gradle`.
- **Rejected input:** `--mc` on a plain mod, and an unknown version.
- **Bot harness:** `readDevServer(modDir, mc)` in `scripts/loadtest/lib/devserver.js` resolves the
  run directory the same way, with `DEV_MC` as the environment fallback, so existing bot scripts work
  per version unchanged. Both READMEs say so.
- **Checked on 2026-10-19:**
  - 26.3 start, rcon, mixins, status and stop on the spike;
  - 26.2 by default, which logged the 26.2 code path;
  - both rejections;
  - `status` on better-barriers, unchanged.
- One spike port collided with another session's dev server (25790, rkcore-menu), so pick dev ports
  with `setup.sh`'s high-water mark or the opt-in script's.

## S4 — Lint for versioned blocks — **done**

**Build.** In `scripts/lint`, exempt Stonecutter blocks from the `/* */` rule. Either a
`SuppressWithPlainTextCommentFilter` scoped to that check between `//? … {` and `//?}`, or a pattern
that allows `/*` right after a `//?` line. Everything else in versioned code stays linted.

**Done when.** The spike's source passes lint except for its deliberate style faults, and a stray
`/* */` outside a versioned block still fails.

### As built

Two edits to `scripts/lint/checkstyle.xml`:
- A `SuppressWithNearbyTextFilter` (`nearbyTextPattern` `^\s*(\*/)?//\?`, `lineRange` 1) scoped to
  `RegexpSinglelineJava`, so only the line right after a `//?` line may open with `/*`.
- The rule's pattern also lets `/*?` (Stonecutter's inline condition) through.

Checked on 2026-10-19:
- A file with an if/else block and a one-line form, otherwise clean, passed.
- A file with a bare `/* */` line, and one right after an ordinary `//` comment, failed on both.
- `lintAll --continue` fails only on rk-tweaks, whose faults (import order, Javadoc, braces and one
  real `/* */`) predate this. The other twelve mods pass.

## S5 — Scaffold and docs — **done**

**Build.**
- `setup.sh` on `main` can opt a new mod in: per-mod controller, `versions/<v>/gradle.properties`
  and `.gitignore` entries for `versions/*/build` and `versions/*/run`.
- Document opting in and switching in `docs/BUILDING.md` (the `template` branch), in the workspace
  `docs/STYLE.md` (how to write `//?` blocks) and in `CLAUDE.md` "Shared build logic".
- **Rule to document:** commit only with the active version reset to `stonecutter_vcs_version`
  ("Reset active project"), so the tree in git stays one version's code.

**Done when.** A mod made with `setup.sh` and the opt-in builds both versions.

### As built

**`gradle/stonecutter-opt-in.sh [--key k]… <extra-version>…`** (`2d309ed`) is shared by `setup.sh`,
S6 and S7.
- It moves the per-version keys that are present into `versions/<base>/gradle.properties`:
  `minecraft_version`, `fabric_version`, `polymer_version`, `bil_version`, `kalic0re_version`,
  `datapack_format` and the dev datapack/options versions.
- It gives each extra version `FILL_IN` for the other moved keys. Dev ports are not per version:
  every run picks the first free pair in `dev_server_ports`.
- It adds the `stonecutter_*` keys and `dev.kikugie.stonecutter.hard_mode=true`, plus the
  controller.
- It appends `.gitignore` patterns only where `git check-ignore` says `build/` and `run/` aren't
  already covered (the template's own `.gitignore` covers both).
- The placeholder is `FILL_IN`, not `CHANGEME`, which `setup.sh` renames everywhere. `setup.sh`
  also runs the opt-in after that rename.

**`setup.sh`** (template `main`, branch `setup-stonecutter`, `9172066`) asks for extra versions,
and a blank answer keeps a single-version mod. `TEMPLATE_URL` and `TEMPLATE_GRADLE_BRANCH` let an
unpushed template be tried.

**Docs:**
- the workspace `docs/STYLE.md` "Multi-version builds (Stonecutter)" (opting in, `//?` blocks,
  switching, the commit rule, dev servers, forks);
- `docs/BUILDING.md` on branch `template-stonecutter` (what a mod records);
- `CLAUDE.md` "Shared build logic".

Checked on 2026-10-19:
- `setup.sh` ran from a local bare copy of the template with the answer `26.3`.
- The new mod built `scnew-0.1.0+26.2.jar`, and `:26.3:build` passed with Polymer 0.18.4 (bil's
  26.2 build stood in, since bil has no 26.3 build).
- On a better-barriers copy, the opt-in's 26.2 jar matches the plain build in every class and
  resource. Only `MANIFEST.MF` and the `+26.2` version string differ.

## S6 — kalic0re for both versions — **done**

**Build.** Opt kalic0re in and publish `kalic0re-<ver>+<mc>` to mavenLocal for each version. Every
mod's `kalic0re_version` moves into `versions/<v>/gradle.properties`. Its datapack zip
(`datapackZip`) is version-specific through `datapack_format`.

**Done when.** A shading mod builds against the matching kalic0re for each version, and the
`check-carrier-copies.sh` copies still agree.

### As built

kalic0re branch `stonecutter`, worktree `rkc/mods/kalic0re/.claude/worktrees/stonecutter`: `17b9861`
for the build and `1fcd192` for the port. Not merged.

**26.3 opt-in:** Fabric API 0.161.0+26.3, Polymer 0.18.4+26.3 and `datapack_format` 121 (26.3's data
format; data version 5023). `build.mod.gradle` reads the resource packs through `rootProject.file`.

**26.3 compile fixes**, each a `//?` block unless noted:
- `PushReaction.BLOCK` became `IMMOVEABLE` (a versioned constant in `PortalBlock`).
- Block codecs are gone, so `PortalBlock.codec()` and its import are 26.2-only.
- `LootContext.getOptionalParameter` became `getOptional`.
- `DataComponentPatch.entrySet()` is gone. `CargoCartItem` now reads
  `split().added().get(ITEM_NAME)`, which works on both versions, so it needs no block.
- Recipe datagen takes `BootstrapContext`s (`ArmorDyeRecipeProvider`).
- Chests submit a separate crumbling overlay (`PolymerChestRenderer`, as vanilla 26.3 does).

**Gap:** the Shadow enchantment's client renderers (`HiddenRendering`, `HiddenEquipmentRendering`,
`HiddenItemRendering`) are wrapped whole in `//? if <26.3`. 26.3 removed `RenderPipeline`,
`BindGroupLayout`, `ColorTargetState`, `DepthStencilState` and `PrimitiveTopology`. artifacts
therefore can't build for 26.3 until those are ported to 26.3's render system. Stonecutter escapes
nested comments (`/^*`, `^/`), so a whole-file block is safe.

**Publishing.** Published to mavenLocal as `club.rainbowkitty.kalic0re:kalic0re:0.31.0+26.2` and
`+26.3`. The shared build needed `artifactId = project.mod_id` (`194e705`): a version node's
publication defaulted to the node's name (`26.2`).

**Checked on 2026-10-19:**
- Lint passes on the versioned source.
- `check-carrier-copies.sh` matches.
- polymer-diagonal-walls shades the same 10 command/text classes from each version's kalic0re
  (S7).

## S7 — First real mod: polymer-diagonal-walls — **done**

**Build.**
- Opt it in with 26.2 and 26.3, Polymer `0.17.5+26.2` and `0.18.x+26.3`.
- Mark any version differences with `//? if`, in mixin targets and the Polymer 0.18 API.
- Its dev server port moves into `versions/26.2/gradle.properties`, and 26.3 gets its own.

**Done when.**
- Both jars build.
- Both dev servers boot with every mixin applied.
- On 26.2, `columns-check.js` passes and the lattice checks match S15 and S19.
- On 26.3, a dev client sees arms and is blocked by the columns.

### As built

polymer-diagonal-walls branch `stonecutter`, worktree
`rkc/mods/polymer-diagonal-walls/.claude/worktrees/stonecutter`: `a79f94a` (build), `090012d`
(`layouts.sh` and `seal-legs.sh` take `DEV_MC`) and `1d2d21c` (`docs/BUILDING.md`). The source
compiles unchanged on 26.3 with Polymer 0.18.4.

Observed on 2026-10-19:
- **Builds:** both jars build, each shading its own version's kalic0re.
- **26.2 equals main:** the 26.2 jar matches a plain build of `main` in every class, mixin and
  resource. Only the manifest, the `+26.2` version string and kalic0re's reshaped
  `PermissionCondition` differ. So S15's and S19's lattice numbers stand for it unchanged.
- **Boot:** both dev servers boot with every mixin applied. The only warnings are the Axiom
  `@Pseudo` targets, absent as expected.
- **26.2 checks:**
  - layouts 18/18;
  - `drawn` 51/51;
  - `stats` 49 holders and 51 arms;
  - `live` 9/9;
  - `columns-check.js` 34/34.
- **26.3 checks:** the same layouts, `drawn`, `stats` and `live` results, plus:
  - `seal-legs.sh` items and arrows stopped on their side at wall A and fence H;
  - all 30 animals stayed inside diamond G over 12,047 sprinted ticks.
- `columns-check.js` can't run on 26.3: ViaFabric 0.4.22 has no 26.3 server module for its 26.1
  bots.

The user confirmed on 2026-10-19, in a 26.3 client joined directly to the 26.3 dev server, that
the arms show and the columns block.

## S8 — Datagen mods — **planned**

**Build.** Decide whether datagen output (`src/main/generated`) is shared or per version, since
Loom's default puts it under each node. Then convert one datagen mod (companions or artifacts).

**Done when.** That mod's generated assets are byte-identical on 26.2 to before, and present on 26.3.

## S9 — `rkc/26.3` fork build — **planned**

**Build.** In `rkc/forks/polymer`, merge every `-26.3` twin into an `rkc/26.3` branch, the way
`rkc/26.2` merges their originals. Do the same for the ppb and enderscape-patch forks if their fixes
are needed on 26.3. Only needed once a 26.3 server must run the fork's fixes. Until then, 26.3 dev
servers use stock Polymer from Maven.

**Done when.** The bundle builds and a 26.3 dev server with it boots.

## Open decisions

- **Per-version keys:** `versions/<v>/gradle.properties` (chosen in S2, since it keeps every
  `project.<key>` read) or Stonecutter 0.9's `stonecutter.properties.toml` (centralized, but read
  through `sc.properties`).
- **Kotlin DSL:** Stonecutter recommends it. The spike shows Groovy works, so stay unless S2–S8 hit a
  Groovy-only problem.
- **Which version is committed:** `stonecutter_vcs_version` is the live server's version, 26.2
  today. Move it when the network moves.

## Reference: commands

- Build every version: `./gradlew build`. One version: `./gradlew :26.3:build`.
- Switch the source tree: `./gradlew "Set active project to 26.3"`. Back to the committed version:
  `./gradlew "Reset active project"`.
- Run a version's dev server: `./gradlew :26.3:runServer`, stop with `./gradlew :26.3:stopServer`
  (`scripts/devserver.sh --mc 26.3` after S3).
- Jars: `versions/<v>/build/libs/<id>-<ver>+<v>.jar`.
