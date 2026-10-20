#!/usr/bin/env bash
# Shared steps of a mod's tag workflows (.github/workflows/publish-maven.yml and release.yml), run
# from the mod root so the logic is versioned with the build:
#
#   gradle/ci/release.sh env              check the tag is v<mod_version>; write RELEASE_VERSION,
#                                         JAVA_VERSION and PRERELEASE to $GITHUB_ENV
#   gradle/ci/release.sh gradle <task>…   run datagen first if the mod has it, then each task once
#                                         per Stonecutter version node (or as given for one version)
#   gradle/ci/release.sh jars             the jars a GitHub release attaches, one per line
set -euo pipefail

[[ -f gradle.properties ]] || { echo "run from the mod root" >&2; exit 2; }

prop() {
    sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p" gradle.properties \
        | head -n1
}

# One Stonecutter version per line; nothing for a single-version build.
versions() {
    prop stonecutter_versions | tr ',' '\n' | sed 's/[[:space:]]//g; /^$/d'
}

# Each task once per version node (":26.2:build"), or as given for a single-version build.
node_tasks() {
    local -a prefixes
    mapfile -t prefixes < <(versions | sed 's/.*/:&:/')
    [[ ${#prefixes[@]} -gt 0 ]] || prefixes=("")
    local prefix task
    for prefix in "${prefixes[@]}"; do
        for task in "$@"; do
            printf '%s%s\n' "$prefix" "$task"
        done
    done
}

case "${1:-}" in
    env)
        mod_version=$(prop mod_version)
        java_version=$(prop java_version)
        [[ -n $mod_version && -n $java_version ]] || {
            echo "gradle.properties lacks mod_version or java_version" >&2
            exit 1
        }
        if [[ ${GITHUB_REF_NAME:-} != "v$mod_version" ]]; then
            echo "Tag ${GITHUB_REF_NAME:-<none>} does not match mod_version $mod_version" >&2
            exit 1
        fi
        {
            echo "RELEASE_VERSION=$mod_version"
            echo "JAVA_VERSION=$java_version"
            # A semver pre-release (0.2.0-beta.1) makes a GitHub pre-release.
            [[ $mod_version == *-* ]] && echo "PRERELEASE=true" || echo "PRERELEASE=false"
        } >> "$GITHUB_ENV"
        ;;
    gradle)
        shift
        [[ $# -gt 0 ]] || { echo "name at least one task" >&2; exit 2; }
        if [[ -n $(prop enable_datagen) ]]; then
            # Never generateAssets and build in one invocation: processResources would run first and
            # the jar would miss the output. Client datagen boots a real client, so it needs a display.
            mapfile -t datagen < <(node_tasks generateAssets)
            if [[ $(prop datagen_client) == true ]] && command -v xvfb-run > /dev/null; then
                xvfb-run -a ./gradlew --no-daemon "${datagen[@]}"
            else
                ./gradlew --no-daemon "${datagen[@]}"
            fi
        fi
        mapfile -t tasks < <(node_tasks "$@")
        ./gradlew --no-daemon "${tasks[@]}"
        ;;
    jars)
        mapfile -t dirs < <(versions | sed 's#.*#versions/&/build/libs#')
        [[ ${#dirs[@]} -gt 0 ]] || dirs=(build/libs)
        # The plain <mod_id>-<version>.jar is the one to install; -unshaded, -sources and -dev are not.
        find "${dirs[@]}" -maxdepth 1 -name '*.jar' ! -name '*-sources.jar' ! -name '*-unshaded.jar' \
            ! -name '*-dev.jar' ! -name '*-javadoc.jar' | sort
        ;;
    *)
        sed -n '2,10p' "$0" >&2
        exit 2
        ;;
esac
