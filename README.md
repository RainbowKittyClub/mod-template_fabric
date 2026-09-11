# Using fabric_mod_skeleton

This repo is split across three branches:

- **`main`** — the actual mod template: build config, source, docs, and its own `README.md`
  covering what the shipped example code does.
- **`gradle`** — the Gradle wrapper and shared `devserver.gradle`, meant to be added as a
  submodule, not cloned on its own.
- **`setup`** (this branch) — nothing but these instructions and `setup.sh`, so a fresh clone of
  `main` doesn't have to carry them.

## Turning this into a new mod

```
git clone fabric_mod_skeleton rkc/mods/<name>   # run from the minecraft-dev workspace root
cd rkc/mods/<name>
rm -rf .git && git init
git submodule add -b gradle ssh://git@github.com/RainbowKittyClub/mod-template_fabric gradle
git config core.hooksPath ../../../scripts/githooks   # git init doesn't inherit this
```

`setup.sh` on this branch automates the last three lines. After the `git clone` above:

```
git show origin/setup:setup.sh | bash
```

Mod ids are conventionally one lowercase word (`rktweaks`, `companions`); the directory may be
hyphenated, and the package always drops separators.

## Renaming the placeholders

Every project-specific string is the literal placeholder `CHANGEME`, or lowercase `changeme` where
a lowercase identifier is required (`mod_id`, package segments, the mixins json filename). Find and
replace across the whole tree, including filenames — exclude `.git` and the `gradle` submodule,
which has none:

```
grep -rl CHANGEME . --exclude-dir={.git,gradle}
grep -rl changeme . --exclude-dir={.git,gradle}
```

At minimum, rename:

- `gradle.properties` — `mod_name`, `mod_description`, `mod_authors`, `mod_website`, `mod_issues`, `mod_license`, `maven_group`, `mod_id`, `entrypoint`
- `settings.gradle` — `rootProject.name`
- `src/main/java/club/rainbowkitty/changeme/CHANGEME.java` — move to match the new package/class name, update `MOD_ID`
- `src/main/resources/changeme.mixins.json` — rename the file, update `package`, update the reference in `fabric.mod.json`'s `mixins` array
- `src/datagen/java/club/rainbowkitty/changeme/datagen/CHANGEMEDataGenerator.java` — move to match the new package/class name, update the `fabric-datagen` entry in `fabric.mod.json`

Then replace `main`'s `README.md`: delete it and rename `README.template.md` to `README.md`. That
template is the new mod's own README — what the mod does and how to install it. Build specifics go
in `docs/BUILDING.md` (carried along with the clone); feature plan docs go under `docs/plan/` (see
`PLANNING.md`).
