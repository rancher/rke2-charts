#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 || ! -d $1 ]]; then
    echo "usage: bash strip-descriptions.sh PATH_TO_CRD_TEMPLATES" >&2
    exit 2
fi

for dependency in jq yq find sort cmp gawk; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        echo "error: missing dependency: $dependency" >&2
        exit 1
    fi
done
# Source locations depend on Mike Farah's yq v4 metadata operators.
if [[ $(yq --version) != *"github.com/mikefarah/yq/"*"version v4."* ]]; then
    echo "error: https://github.com/mikefarah/yq is required" >&2
    exit 1
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temporary_directory=$(mktemp -d)
temporary_files=()
cleanup() {
    if ((${#temporary_files[@]})); then
        rm -f -- "${temporary_files[@]}"
    fi
    rmdir -- "$temporary_directory"
}
trap cleanup EXIT

files_list="$temporary_directory/files"
input_json="$temporary_directory/input.json"
paths_json="$temporary_directory/paths.json"
expected_json="$temporary_directory/expected.json"
actual_json="$temporary_directory/actual.json"
key_locations="$temporary_directory/keys.json"
selected_lines="$temporary_directory/lines.tsv"
temporary_files+=("$files_list" "$input_json" "$paths_json" "$expected_json" "$actual_json" "$key_locations" "$selected_lines")
# Null delimiters handle unusual filenames; sorting makes processing order deterministic.
find "$1" \( -name '*.yaml' -o -name '*.yml' \) ! -type d -print0 | sort -z > "$files_list"

files=()
outputs=()
counts=()
total=0
while IFS= read -r -d '' file; do
    if [[ ! -f $file || -L $file ]]; then
        echo "error: $file: expected a regular YAML file" >&2
        exit 1
    fi
    yq --header-preprocess=false -o=json '.' "$file" > "$input_json"
    # Schema-aware selection avoids stripping matching text outside approved description fields.
    jq -s --slurpfile striplist "$script_dir/strip-descriptions.json" \
        -f "$script_dir/strip-descriptions.jq" "$input_json" > "$paths_json"
    count=$(jq '[.[] | length] | add // 0' "$paths_json")
    if ((count == 0)); then
        continue
    fi
    output="$temporary_directory/output-${#outputs[@]}.yaml"
    temporary_files+=("$output")
    # Map selected paths to source lines so surviving YAML never needs reserialization.
    yq --header-preprocess=false -o=json \
        '... | select(is_key and . == "description") | {"document": documentIndex, "path": path, "line": line, "column": column}' \
        "$file" > "$key_locations"
    jq -r -s --slurpfile paths "$paths_json" \
        '.[] | select(.path as $path | $paths[0][.document] | index([$path])) | [.line, .column] | @tsv' \
        "$key_locations" > "$selected_lines"
    if [[ $(gawk 'END { print NR }' "$selected_lines") != "$count" ]]; then
        echo "error: $file: could not locate every striplisted description in the YAML source" >&2
        exit 1
    fi
    # Edit source bytes directly to preserve whitespace, line endings, and scalar formatting.
    gawk -f "$script_dir/strip-descriptions.awk" "$selected_lines" "$file" > "$output"

    # Compare parsed documents to catch accidental changes beyond the selected descriptions.
    jq -S -s --slurpfile paths "$paths_json" \
        '[to_entries[] | .key as $index | .value | delpaths($paths[0][$index])]' \
        "$input_json" > "$expected_json"
    yq --header-preprocess=false -o=json '.' "$output" | jq -S -s '.' > "$actual_json"
    if ! cmp -s "$expected_json" "$actual_json"; then
        echo "error: $file: stripping would change content beyond striplisted schema descriptions" >&2
        exit 1
    fi
    files+=("$file")
    outputs+=("$output")
    counts+=("$count")
    total=$((total + count))
done < "$files_list"

# Stage every result before writing, so validation failures leave all source files untouched.
for index in "${!files[@]}"; do
    cat -- "${outputs[index]}" > "${files[index]}"
    printf '%s: removed %d descriptions\n' "${files[index]}" "${counts[index]}"
done
printf 'Removed %d striplisted descriptions from %d files\n' "$total" "${#files[@]}"
