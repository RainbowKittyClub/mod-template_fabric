#!/usr/bin/env bash
# Run from inside a fresh `git clone` of fabric_mod_skeleton's main branch, before committing
# anything else. Detaches the checkout from the template's own history and wires up the shared
# gradle/ submodule. See this branch's README.md for what this does command-by-command, and for
# the placeholder-renaming steps it does NOT do.
set -euo pipefail

template_url="ssh://git@github.com/RainbowKittyClub/mod-template_fabric"

rm -rf .git
git init -q
git submodule add -q -b gradle "$template_url" gradle
git config core.hooksPath ../../../scripts/githooks

echo "Detached from the template and added gradle/ as a submodule."
echo "Next: rename the CHANGEME/changeme placeholders (see this repo's setup branch README), then git add -A && git commit."
