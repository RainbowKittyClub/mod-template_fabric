# gradle (shared build boilerplate)

Everything generic enough to be identical across every mod built from `fabric_mod_skeleton`:
the Gradle wrapper (`gradlew`, `gradlew.bat`, `gradle/wrapper/`), `devserver.gradle`, `build.gradle`,
`settings.gradle`, and `gradle.properties.template` (the `CHANGEME`-templated `gradle.properties`,
named `.template` here so it's never mistaken for a real one).

Not meant to be cloned or built on its own — a consuming repo adds this branch as a submodule at
`gradle/`:

```
git submodule add -b gradle ssh://git@github.com/RainbowKittyClub/mod-template_fabric gradle
```

## Why `gradle/wrapper/` is nested one level deeper than you'd expect

`gradlew`/`gradlew.bat`, `build.gradle` and `settings.gradle` are meant to be **symlinked**, not
copied, from the consuming repo's root into this submodule — that's the whole point of the split:
one canonical copy, versioned here, never forked per mod. `setup.sh` on the `main` branch does:

```
ln -s gradle/gradlew gradlew
ln -s gradle/gradlew.bat gradlew.bat
ln -s gradle/build.gradle build.gradle
ln -s gradle/settings.gradle settings.gradle
```

The standard `gradlew` script resolves its own symlink chain to find its *real* location, then looks
for the wrapper jar at `<that real location>/gradle/wrapper/gradle-wrapper.jar`. Once symlinked, its
real location is this submodule's root — so the jar has to live at this submodule's own
`gradle/wrapper/gradle-wrapper.jar`, not at a bare `wrapper/` one level up. (`devserver.gradle` has no
such constraint: it's pulled in by `build.gradle`'s `apply from: 'gradle/devserver.gradle'`, which
Gradle resolves against the *project* directory — wherever the build was invoked from — not against
wherever the physical `build.gradle` file lives. So it stays at this submodule's own root, which
lands at the consuming repo's `gradle/devserver.gradle` once mounted.)

`settings.gradle` has no `CHANGEME` placeholder of its own for the same reason it's symlinked rather
than copied: `rootProject.name` is derived at build time from `gradle.properties`'s `mod_id`, which
*is* real per-mod state — copied, not symlinked, since a symlink here would mean every mod fighting
over one shared file.

See the `main` branch for the full new-mod bootstrap sequence.
