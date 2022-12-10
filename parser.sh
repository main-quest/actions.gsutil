#!/bin/bash

set -euo pipefail

key="$1"

kf=$(mktemp)
printf '[Debug] Interpret "\\n" strings as literal LF to %s' "$kf"
echo -e "$key" > "$kf"

prefix="\"project_id\":"

# Important to do this, as grep returns non-zero if no match is found
echo "[Debug] Find project line in suppposedly non-encripted key"
line=$(grep -F "$prefix" "$kf" || echo '')

echo "[Debug] Test line"
if [ -z "$line" ]; then
    # We are dealing with a base64 string, probably
    echo "[Debug] Decoding supposedly base64 key"
    f=$(mktemp)

    # sed cannot match "\n" because it's a line-by-line tool, but '$' can be used in the to-be-replaced section to signify (Unix) the end of line
    # As per https://stackoverflow.com/a/44209944
    printf '[Debug] Removing any "\\r" char from the end of the lines: from %s to %s' "$kf" "$f"
    sed 's/\r$//g' "$kf" > "$f"

    # printf '[Debug] Replacing any potential literal "\\n" strings with an actual \\n char (LF): from %s to %s' "$kf" "$f"
    # sed 's/\\n/\n/g' "$kf" > "$f"

    f2=$(mktemp)
    echo "[Debug] Decoding $f to $f2"
    base64 -d < "$f" > "$f2"

    echo "[Debug] Find project line in decripted key"
    set +e
    line=$(grep -F "$prefix" "$f2" || echo '')
    set -e
    
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