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

## S3 — `devserver.sh` per version — **planned**

**Build.** Add `--mc <v>` to `scripts/devserver.sh`:
- run directory `versions/<v>/run`;
- launch marker `<root>/.gradle/loom-cache/projects/<v>/launch.cfg`;
- tasks `:<v>:runServer` and `:<v>:stopServer`.

Without `--mc`, a Stonecutter mod uses its `stonecutter_vcs_version`, and a plain mod is unchanged.

**Done when.** `start`, `rcon`, `logs`, `mixins` and `stop` work for both versions of the spike, and
for one plain mod.

## S4 — Lint for versioned blocks — **planned**

**Build.** In `scripts/lint`, exempt Stonecutter blocks from the `/* */` rule. Either a
`SuppressWithPlainTextCommentFilter` scoped to that check between `//? … {` and `//?}`, or a pattern
that allows `/*` right after a `//?` line. Everything else in versioned code stays linted.

**Done when.** The spike's source passes lint except for its deliberate style faults, and a stray
`/* */` outside a versioned block still fails.

## S5 — Scaffold and docs — **planned**

**Build.**
- `setup.sh` on `main` can opt a new mod in: per-mod controller, `versions/<v>/gradle.properties`
  and `.gitignore` entries for `versions/*/build` and `versions/*/run`.
- Document opting in and switching in `docs/BUILDING.md` (the `template` branch), in the workspace
  `docs/STYLE.md` (how to write `//?` blocks) and in `CLAUDE.md` "Shared build logic".
- **Rule to document:** commit only with the active version reset to `stonecutter_vcs_version`
  ("Reset active project"), so the tree in git stays one version's code.

**Done when.** A mod made with `setup.sh` and the opt-in builds both versions.

## S6 — kalic0re for both versions — **planned**

**Build.** Opt kalic0re in and publish `kalic0re-<ver>+<mc>` to mavenLocal for each version. Every
mod's `kalic0re_version` moves into `versions/<v>/gradle.properties`. Its datapack zip
(`datapackZip`) is version-specific through `datapack_format`.

**Done when.** A shading mod builds against the matching kalic0re for each version, and the
`check-carrier-copies.sh` copies still agree.

## S7 — First real mod: polymer-diagonal-walls — **planned**

**Build.**
- Opt it in with 26.2 and 26.3, Polymer `0.17.5+26.2` and `0.18.x+26.3`.
- Mark any version differences with `//? if`, in mixin targets and the Polymer 0.18 API.
- Its dev server port moves into `versions/26.2/gradle.properties`, and 26.3 gets its own.

**Done when.**
- Both jars build.
- Both dev servers boot with every mixin applied.
- On 26.2, `columns-check.js` passes and the lattice checks match S15 and S19.
- On 26.3, a dev client sees arms and is blocked by the columns.

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
