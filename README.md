# gradle (shared build boilerplate)

Everything generic enough to be identical across every mod built from `fabric_mod_skeleton`:
the Gradle wrapper (`gradlew`, `gradlew.bat`, `wrapper/`), `devserver.gradle`, `build.gradle`,
`settings.gradle`, and `gradle.properties.template` (the `CHANGEME`-templated `gradle.properties`,
named `.template` here so it's never mistaken for a real one).

Not meant to be cloned or built on its own — a consuming repo adds this branch as a submodule at
`gradle/`:

```
git submodule add -b gradle ssh://git@github.com/RainbowKittyClub/mod-template_fabric gradle
```

Two different consumption patterns live side by side here, because Gradle's CLI only looks for
`build.gradle`/`settings.gradle` in the current directory, never in a subdirectory:

- `wrapper/gradle-wrapper.jar`, `wrapper/gradle-wrapper.properties` and `devserver.gradle` are read
  straight out of `gradle/` in place — `gradlew` (once copied to the repo root, see below) expects
  the wrapper jar at `gradle/wrapper/gradle-wrapper.jar`, and the copied `build.gradle` pulls in
  `devserver.gradle` with `apply from: 'gradle/devserver.gradle'`.
- `gradlew`, `gradlew.bat`, `build.gradle`, `settings.gradle` and `gradle.properties.template` are
  meant to be copied out to the repo root, not referenced in place — `setup.sh` on the `main` branch
  does this. `gradle.properties.template` becomes the root's own `gradle.properties`; the rest copy
  over unchanged (nothing in them is mod-specific — `settings.gradle`'s `rootProject.name` is still
  the literal `changeme` placeholder, renamed same as everything else).

See the `main` branch for the full new-mod bootstrap sequence.
