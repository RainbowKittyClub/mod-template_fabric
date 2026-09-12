#!/usr/bin/env bash
# Run from inside a fresh `git clone` of fabric_mod_skeleton (this, the main branch), before
# committing anything else. See README.md for what this does command-by-command, why the gradle
# submodule's files are symlinked rather than copied, and the placeholder-renaming step this does
# NOT do.
set -euo pipefail

template_url="ssh://git@github.com/RainbowKittyClub/mod-template_fabric"

# Vendor the template branch's files (source, docs, its future README.template.md) into the
# working tree. This branch has no README.md of its own for checkout to collide with - the doc
# you're reading now stays put until the very last line of this script replaces it.
git fetch -q "$template_url" template
git checkout -q FETCH_HEAD -- .

# Detach from the template's own history now that both branches' files are in place.
rm -rf .git
git init -q

# Wire up the shared gradle submodule. Its build.gradle/settings.gradle/wrapper scripts are
# symlinked in, not copied, so they stay versioned in exactly one place instead of forking per mod;
# only gradle.properties is real per-mod state, so it's copied (from the CHANGEME-templated
# gradle.properties.template) rather than symlinked.
git submodule add -q -b gradle "$template_url" gradle
ln -s gradle/gradlew gradlew
ln -s gradle/gradlew.bat gradlew.bat
ln -s gradle/build.gradle build.gradle
ln -s gradle/settings.gradle settings.gradle
cp gradle/gradle.properties.template gradle.properties

git config core.hooksPath ../../../scripts/githooks

# This branch's job is done - hand off to the template's own README.
mv README.template.md README.md

echo "Template pulled in, gradle/ submodule wired up, build files symlinked into place."
echo "Next: rename the CHANGEME/changeme placeholders (see README.md), then git add -A && git commit."

rm -- "$0"
