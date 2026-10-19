#!/usr/bin/env bash
# Opts this mod into multi-version builds (Stonecutter), from the mod's root:
#
#   gradle/stonecutter-opt-in.sh [--key <name>]... <extra-version>...
#
# The mod's current minecraft_version becomes the committed version (stonecutter_vcs_version), and
# each <extra-version> gets its own node under versions/. Keys that differ per version move from
# gradle.properties into versions/<v>/gradle.properties: the list below plus any --key. For an extra
# version, minecraft_version and the dev ports are filled in; every other moved key is FILL_IN, for
# the dependency version that matches that Minecraft version.
set -euo pipefail

per_version_keys=(minecraft_version fabric_version polymer_version bil_version kalic0re_version
    datapack_format dev_server_port dev_rcon_port dev_datapack_pack_format dev_client_options_version)
extras=()
while [[ $# -gt 0 ]]; do
    case $1 in
        --key) per_version_keys+=("$2"); shift 2 ;;
        -*) echo "unknown option $1" >&2; exit 2 ;;
        *) extras+=("$1"); shift ;;
    esac
done
[[ ${#extras[@]} -gt 0 ]] || { sed -n '2,10p' "$0" >&2; exit 2; }
[[ -f gradle.properties && -L settings.gradle ]] || { echo "run from a mod's root" >&2; exit 1; }
[[ ! -e stonecutter.gradle ]] || { echo "already opted in (stonecutter.gradle exists)" >&2; exit 1; }

prop() { grep -m1 -E "^$1 ?=" gradle.properties | cut -d= -f2- | sed 's/^ //'; }
base=$(prop minecraft_version)
[[ -n $base ]] || { echo "no minecraft_version in gradle.properties" >&2; exit 1; }

# Same high-water mark as setup.sh, now also over every sibling's per-version files. Siblings are
# found beside the main checkout, so this also works from a worktree under .claude/worktrees/.
mods_dir=..
if common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    mods_dir=$(dirname "$(dirname "$common")")
fi
highest=0
shopt -s nullglob
for f in "$mods_dir"/*/gradle.properties "$mods_dir"/*/versions/*/gradle.properties gradle.properties; do
    [[ -f $f ]] || continue
    for v in $(grep -E '^dev_(server|rcon)_port=' "$f" 2>/dev/null | cut -d= -f2); do
        (( v > highest )) && highest=$v
    done
done

mkdir -p "versions/$base"
moved=()
for key in "${per_version_keys[@]}"; do
    if grep -qE "^$key ?=" gradle.properties; then
        moved+=("$key")
        grep -m1 -E "^$key ?=" gradle.properties >> "versions/$base/gradle.properties"
    fi
done
for key in "${moved[@]}"; do
    sed -i -E "/^$key ?=/d" gradle.properties
done

todo=()
for v in "${extras[@]}"; do
    [[ $v != "$base" ]] || { echo "$v is already the base version" >&2; exit 1; }
    mkdir -p "versions/$v"
    : > "versions/$v/gradle.properties"
    for key in "${moved[@]}"; do
        case $key in
            minecraft_version) value=$v ;;
            dev_server_port) highest=$((highest + 2)); value=$highest ;;
            dev_rcon_port) highest=$((highest + 2)); value=$highest ;;
            *) value=FILL_IN; todo+=("versions/$v/gradle.properties: $key") ;;
        esac
        echo "$key=$value" >> "versions/$v/gradle.properties"
    done
done

if ! grep -q '^stonecutter_version=' gradle.properties; then
    grep -m1 '^stonecutter_version=' gradle/gradle.properties.template >> gradle.properties
fi
versions=$(IFS=,; echo "$base,${extras[*]}")
{
    echo "# Multi-version build: one node per version under versions/, see gradle/stonecutter-opt-in.sh."
    echo "stonecutter_versions=$versions"
    echo "stonecutter_vcs_version=$base"
    echo "dev.kikugie.stonecutter.hard_mode=true"
} >> gradle.properties

# The controller is per mod, never symlinked: Stonecutter rewrites its active line on every switch.
cat > stonecutter.gradle <<EOF
plugins {
    id 'dev.kikugie.stonecutter'
}

stonecutter.active '$base' /* [SC] DO NOT EDIT */
EOF

# Most mods already ignore build/ and run/ at any depth; add the per-version patterns only if not.
if git rev-parse --git-dir >/dev/null 2>&1; then
    for name in build run; do
        if ! git check-ignore -q "versions/$base/$name/x" && ! grep -qxF "/versions/*/$name/" .gitignore 2>/dev/null; then
            echo "/versions/*/$name/" >> .gitignore
        fi
    done
fi

echo "Opted in: versions $versions, committed version $base."
echo "Moved per-version keys: ${moved[*]}"
if [[ ${#todo[@]} -gt 0 ]]; then
    echo "Fill in before building (Gradle configures every version, so one FILL_IN stops them all):"
    printf '  %s\n' "${todo[@]}"
fi
echo "Build all with ./gradlew build; switch the tree with ./gradlew \"Set active project to <v>\"."
