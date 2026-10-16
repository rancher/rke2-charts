#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
temporary_directory=$(mktemp -d)
trap 'rm -rf -- "$temporary_directory"' EXIT
mkdir "$temporary_directory/crds"

printf '%s\r\n' \
    'apiVersion: example/v1' \
    'kind: Example' \
    'spec:' \
    '        description: "An array of string values. If the operator is In or NotIn, the values array must be non-empty. If the operator is Exists or DoesNotExist, the values array must be empty. If the operator is Gt or Lt, the values array must have a single element, which will be interpreted as an integer. This array is replaced during a strategic merge patch."' \
    '        nested:' \
    '          description: >-' \
    '            An array of string values. If the operator is In or NotIn,' \
    '            the values array must be non-empty. If the operator is Exists or DoesNotExist,' \
    '            the values array must be empty. If the operator is Gt or Lt,' \
    '            the values array must have a single element, which will be interpreted as an integer.' \
    '            This array is replaced during a strategic merge patch.' \
    '          type: array' \
    '        other:' \
    '          description: Keep this description.' \
    '          message: An array of string values.' \
    '---' \
    'kind: AnotherDocument' \
    'description: Keep this too.' \
    > "$temporary_directory/crds/sample.yaml"

printf '%s\r\n' \
    'apiVersion: example/v1' \
    'kind: Example' \
    'spec:' \
    '        nested:' \
    '          type: array' \
    '        other:' \
    '          description: Keep this description.' \
    '          message: An array of string values.' \
    '---' \
    'kind: AnotherDocument' \
    'description: Keep this too.' \
    > "$temporary_directory/expected.yaml"

perl "$script_dir/strip-descriptions.pl" "$temporary_directory/crds"
cmp "$temporary_directory/expected.yaml" "$temporary_directory/crds/sample.yaml"
perl "$script_dir/strip-descriptions.pl" "$temporary_directory/crds"
cmp "$temporary_directory/expected.yaml" "$temporary_directory/crds/sample.yaml"
