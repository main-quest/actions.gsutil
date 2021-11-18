#!/bin/bash

set -e

key="$1"
key_is_encrypted="$2"
project_id="$3"
v_do="$4"


# Storing current dir, as gsutil needs to be ran from it
prev_working_dir="$(pwd)"

# Important to not use quotes
gsutil_user_directory="$HOME/.gsutil"
delete_gsutil_user_dir_after="false"

if [ ! -f "$gsutil_user_directory" ]; then
    if [ ! -d "$gsutil_user_directory" ]; then
    delete_gsutil_user_dir_after="true"
    fi
fi

# Installing as per https://cloud.google.com/storage/docs/gsutil_install

echo "Installing in temp folder so we can simulate a docker image as much as we can (not affecting user environment too much)"
# file_name="gsutil_4.9.tar.gz"
file_name="gsutil_5.5.tar.gz"
url="https://storage.googleapis.com/pub/$file_name"
curl -O "$url"
install_dir=$(mktemp -d)
tar xfz "$file_name" -C "$install_dir"

gsutil_bin_dir="$install_dir"/gsutil
echo "Entering install dir: $gsutil_bin_dir"
cd "$gsutil_bin_dir" || exit 123

echo "Write key to dir"
key_path="$install_dir"/key.json

if [[ "$key_is_encrypted" == "true" ]]; then
    echo "$key" | base64 -d > "$key_path"
else
    echo "$key" > "$key_path"
fi

# echo "Parse email"
# prefix="\"client_email\":"
# line=$(grep -F "$prefix" "$key_path" || echo '')
# echo "[Debug] Remove prefix, double quotes, columns and commas, and new lines from line"
# email=$(echo "$line" | sed -e "s/$prefix//g" -e 's/\"//g' -e 's/\://g' -e 's/\,//g' | xargs echo -n)
# echo "Email is $email"

# echo "Parse PK"
# prefix="\"private_key\":"
# line=$(grep -F "$prefix" "$key_path" || echo '')
# echo "[Debug] Remove prefix, double quotes, columns and commas from line (keeping new lines!), and also any spaces"
# pk=$(echo "$line" | sed -e "s/$prefix//g" -e 's/\"//g' -e 's/\://g' -e 's/\,//g' -e 's/^[[:space:]]*//')

# echo "Write PK to file"
# inner_key_path="$install_dir"/key-inner.json
# printf "%b" "$pk" > "$inner_key_path"

echo "Override credentials inline"
# cmd_proj="GSUtil:default_project_id=$project_id"
# cmd_email="Credentials:gs_service_client_id=$email"
# cmd_key="Credentials:gs_service_key_file=$inner_key_path"
cmd_key="Credentials:gs_service_key_file=$key_path"

echo "Exiting install dir and returning to working dir: $prev_working_dir"
cd "$prev_working_dir" || exit 123

echo "Running: $v_do"
# Commented: found out gsutil 5.5 only needs the key (since email and project are derived from them)
# Note: the last command is specifically left unquoted so that gsutil will pick all spaces
# "$gsutil_bin_dir/gsutil" -o "$cmd_proj" -o "$cmd_email" -o "$cmd_key" $v_do

# Note: disabling parallel processing as it may cause issues on macOS
if [[ $OSTYPE == *"darwin"* ]]; then
    "$gsutil_bin_dir/gsutil" -o "$cmd_key" -o "GSUtil:parallel_process_count=1" $v_do
else
    "$gsutil_bin_dir/gsutil" -o "$cmd_key" $v_do
fi


echo "Deleting the install"
rm -r "$install_dir"

if [ "$delete_gsutil_user_dir_after" == "true" ]; then
    echo "Deleting the auto-created directory by gsutil that didn't previously exist: $gsutil_user_directory"
    rm -r "$gsutil_user_directory"
fi