# Using fabric_mod_skeleton

This repo is split across three branches:

- **`main`** (this branch) — nothing but this file and `setup.sh`. What a plain `git clone` gets you.
- **`template`** — the actual mod template: build config, source, docs, and its own `README.md`
  covering what the shipped example code does. Not meant to be cloned directly; `setup.sh` pulls it
  in.
- **`gradle`** — the Gradle wrapper, `devserver.gradle`, `build.gradle`, `settings.gradle` and
  `gradle.properties.template` — generic enough to be identical across every mod, added as a
  submodule rather than duplicated. Also not meant to be cloned directly.

## Turning this into a new mod

```
git clone fabric_mod_skeleton rkc/mods/<name>   # run from the minecraft-dev workspace root
cd rkc/mods/<name>
./setup.sh
```

`setup.sh` does the rest and then deletes itself:

```
git fetch <template-url> template && git checkout FETCH_HEAD -- .   # pull in the template branch's files
rm -rf .git && git init                                              # detach from the template's own history
git submodule add -b gradle <template-url> gradle                    # wire up the shared build boilerplate
cp gradle/{gradlew,gradlew.bat,build.gradle,settings.gradle} .       # copy out what Gradle needs at the root
cp gradle/gradle.properties.template gradle.properties
git config core.hooksPath ../../../scripts/githooks                  # git init doesn't inherit this
rm -- "$0"
```

Mod ids are conventionally one lowercase word (`rktweaks`, `companions`); the directory may be
hyphenated, and the package always drops separators.

## Renaming the placeholders

Every project-specific string is the literal placeholder `CHANGEME`, or lowercase `changeme` where
a lowercase identifier is required (`mod_id`, package segments, the mixins json filename). Find and
replace across the whole tree, including filenames — exclude `.git` and the `gradle` submodule
(nothing in it needs renaming until it's next synced):

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

Then replace this `README.md`: delete it (it came from the `template` branch's own README, describing
the shipped example code — `setup.sh` already overwrote this branch's bootstrap version with it) and
rename `README.template.md` to `README.md`. That template is the new mod's own README — what the mod
does and how to install it. Build specifics go in `docs/BUILDING.md` (carried along from `template`);
feature plan docs go under `docs/plan/` (see `PLANNING.md`).
