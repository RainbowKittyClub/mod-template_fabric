#!/usr/bin/env bash
# Run from inside a fresh `git clone` of fabric_mod_skeleton (this, the main branch), before
# committing anything else. See README.md for what this does command-by-command, why the gradle
# submodule's files are symlinked rather than copied, and how the prompts below map onto the
# CHANGEME/changeme placeholders.
set -euo pipefail

template_url="ssh://git@github.com/RainbowKittyClub/mod-template_fabric"

sed_escape() { printf '%s' "$1" | sed -e 's/[&#\]/\\&/g'; }

prompt() {
    local var_name=$1 text=$2 default=${3-} pattern=${4-} value
    while true; do
        if [[ -n $default ]]; then
            read -rp "$text [$default]: " value
            value=${value:-$default}
        else
            read -rp "$text: " value
        fi
        if [[ -z $value ]]; then
            echo "  required." >&2
            continue
        fi
        if [[ -n $pattern && ! $value =~ $pattern ]]; then
            echo "  doesn't match $pattern, try again." >&2
            continue
        fi
        break
    done
    printf -v "$var_name" '%s' "$value"
}

# Gather every answer before touching anything, so a Ctrl-C mid-prompt leaves a clean checkout.
echo "Setting up a new mod from fabric_mod_skeleton. Ctrl-C any time to abort without changes."
prompt mod_id "Mod id (one lowercase word, e.g. rktweaks)" "" '^[a-z][a-z0-9]*$'
prompt entry_class "Entrypoint class name" "Main" '^[A-Z][A-Za-z0-9]*$'
prompt mod_name "Display name" "$(tr '[:lower:]' '[:upper:]' <<< "${mod_id:0:1}")${mod_id:1}"
default_author=$(git config user.name 2>/dev/null || true)
prompt mod_authors "Author(s), comma-separated" "${default_author:-}"
prompt mod_description "One-line description" ""
prompt mod_website "GitHub repo URL" "https://github.com/RainbowKittyClub/$mod_id"
prompt mod_license "License" "Unlicense"

# Not prompted: every first-party mod uses this exact group, and the shipped source is already
# laid out under src/main/java/club/rainbowkitty/ - a different group here would mismatch the
# package the entrypoint actually moves to below.
maven_group="club.rainbowkitty.$mod_id"
mod_issues="$mod_website/issues"
IFS=',' read -ra author_list <<< "$mod_authors"
mod_authors_json="["
for i in "${!author_list[@]}"; do
    [[ $i -gt 0 ]] && mod_authors_json+=", "
    mod_authors_json+="\"$(echo "${author_list[$i]}" | sed -e 's/^ *//' -e 's/ *$//')\""
done
mod_authors_json+="]"

# Vendor the template branch's files (source, docs, its future README.template.md) into the
# working tree. This branch has no README.md of its own for checkout to collide with - the doc
# you're reading now stays put until near the end of this script, when it's replaced.
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

# Fill in gradle.properties with the answers above.
sed -i \
    -e "s#^mod_name = .*#mod_name = $(sed_escape "$mod_name")#" \
    -e "s#^mod_description = .*#mod_description = $(sed_escape "$mod_description")#" \
    -e "s#^mod_authors = .*#mod_authors = $(sed_escape "$mod_authors_json")#" \
    -e "s#^mod_website = .*#mod_website = $(sed_escape "$mod_website")#" \
    -e "s#^mod_issues = .*#mod_issues = $(sed_escape "$mod_issues")#" \
    -e "s#^mod_license = .*#mod_license = $(sed_escape "$mod_license")#" \
    -e "s#^maven_group = .*#maven_group = $(sed_escape "$maven_group")#" \
    -e "s#^mod_id = .*#mod_id = $(sed_escape "$mod_id")#" \
    -e "s#^entrypoint = .*#entrypoint = $(sed_escape "$maven_group.$entry_class")#" \
    gradle.properties

# Move the CHANGEME-named source into place under the real package/class names.
mv "src/main/java/club/rainbowkitty/changeme" "src/main/java/club/rainbowkitty/$mod_id"
mv "src/main/java/club/rainbowkitty/$mod_id/CHANGEME.java" \
   "src/main/java/club/rainbowkitty/$mod_id/$entry_class.java"
mv "src/datagen/java/club/rainbowkitty/changeme" "src/datagen/java/club/rainbowkitty/$mod_id"
mv "src/datagen/java/club/rainbowkitty/$mod_id/datagen/CHANGEMEDataGenerator.java" \
   "src/datagen/java/club/rainbowkitty/$mod_id/datagen/${entry_class}DataGenerator.java"
mv "src/main/resources/changeme.mixins.json" "src/main/resources/$mod_id.mixins.json"
mv "src/main/resources/assets/changeme" "src/main/resources/assets/$mod_id"
mv "src/main/resources/data/changeme" "src/main/resources/data/$mod_id"

# Everything else referencing CHANGEME/changeme is plain text: package decls, class references
# (CHANGEME.MOD_ID), the mixins/fabric-datagen entries in fabric.mod.json, resource namespaces.
# Excludes .git and the gradle submodule, which have none.
mapfile -t files < <(grep -rl CHANGEME . --exclude-dir={.git,gradle} 2>/dev/null || true)
[[ ${#files[@]} -gt 0 ]] && sed -i "s/CHANGEME/$entry_class/g" "${files[@]}"
mapfile -t files < <(grep -rl changeme . --exclude-dir={.git,gradle} 2>/dev/null || true)
[[ ${#files[@]} -gt 0 ]] && sed -i "s/changeme/$mod_id/g" "${files[@]}"

# This branch's job is done - hand off to the template's own README.
mv README.template.md README.md

echo
echo "Done. $mod_id is ready at $(pwd):"
echo "  - gradle/ added as a submodule; build.gradle/settings.gradle/wrapper symlinked in"
echo "  - gradle.properties filled in from your answers above"
echo "  - CHANGEME/changeme placeholders renamed throughout"
echo "  - README.md is now README.template.md's stub - fill it in"
echo "Next: review the diff, then git add -A && git commit."

rm -- "$0"
