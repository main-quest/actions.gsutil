#!/bin/bash

set -e

kf=$(mktemp)
echo "$1" > "$kf"
prefix="\"project_id\":"

# Important to do this, as grep returns non-zero if no match is found
echo "[Debug] Find project line in suppposedly non-encripted key"
line=$(grep -F "$prefix" "$kf" || echo '')

echo "[Debug] Test line"
if [ -z "$line" ]; then
    # We are dealing with a base64 string, probably
    echo "[Debug] Decoding supposedly base64 key"
    f=$(mktemp)

    echo "[Debug] Decoding to $f"
    (cat "$kf" | base64 -d > "$f") || echo "decoding failed"

    echo "[Debug] Find project line in decripted key"
    line=$(grep -F "$prefix" "$f" || echo '')
    
    echo "key_is_encrypted=true" >> "$GITHUB_OUTPUT"
else
    echo "key_is_encrypted=false" >> "$GITHUB_OUTPUT"
fi

if [ -z "$line" ]; then
    echo "[Debug] We couldn\'t find \'$prefix\' string in the key file, nor in the decoded version of it. Trying without setting the project id..."
else
    echo "[Debug] Remove prefix, double quotes, columns and commas, and new lines from line"
    project_id=$(echo "$line" | sed -e "s/$prefix//g" -e 's/\"//g' -e 's/\://g' -e 's/\,//g' | xargs echo -n)

    echo "[Debug] Project id found: $project_id"
    echo "project_id=$project_id" >> "$GITHUB_OUTPUT"
fi