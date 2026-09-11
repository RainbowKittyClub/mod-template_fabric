# gradle (shared wrapper + dev-server tasks)

The Gradle wrapper jar/properties and `devserver.gradle` shared by every mod built from
`fabric_mod_skeleton`'s `main` branch. Not meant to be cloned or built on its own — a consuming repo
adds this branch as a submodule at `gradle/`:

```
git submodule add -b gradle ssh://git@github.com/RainbowKittyClub/mod-template_fabric gradle
```

That path matters: the standard `gradlew` script expects `gradle/wrapper/gradle-wrapper.jar`, and
`build.gradle` pulls in `devserver.gradle` with `apply from: 'gradle/devserver.gradle'` — both
resolve once this branch lands at `gradle/`.

See the `setup` branch for the full new-mod bootstrap sequence.
