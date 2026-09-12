#!/usr/bin/env bash
# Run from inside a fresh `git clone` of fabric_mod_skeleton (this, the main branch), before
# committing anything else. Pulls in the template branch's files, detaches from the template's own
# history, wires up the shared gradle/ submodule, copies the boilerplate that has to live at the
# repo root out of it, and deletes itself. See this branch's README.md for the manual equivalent,
# and for the placeholder-renaming step this does NOT do.
set -euo pipefail

template_url="ssh://git@github.com/RainbowKittyClub/mod-template_fabric"

# Vendor the template branch's files (source, docs, its own README) into the working tree,
# overwriting this branch's own README.md in the process — that's expected, it was only ever a
# bootstrap doc.
git fetch -q "$template_url" template
git checkout -q FETCH_HEAD -- .

# Detach from the template's own history now that both branches' files are in place.
rm -rf .git
git init -q

# Wire up the shared gradle submodule, then copy out the pieces Gradle's CLI needs at the repo
# root (it only looks for build.gradle/settings.gradle in the current directory) or that need to
# diverge per mod. The wrapper jar/properties and devserver.gradle stay referenced in place inside
# gradle/ — see the gradle branch's README for why the split falls where it does.
git submodule add -q -b gradle "$template_url" gradle
cp gradle/gradlew gradle/gradlew.bat gradle/build.gradle gradle/settings.gradle .
cp gradle/gradle.properties.template gradle.properties
chmod +x gradlew gradlew.bat

git config core.hooksPath ../../../scripts/githooks

echo "Template pulled in, gradle/ submodule wired up, build files copied into place."
echo "Next: rename the CHANGEME/changeme placeholders (see README.md / README.template.md), then git add -A && git commit."

rm -- "$0"
