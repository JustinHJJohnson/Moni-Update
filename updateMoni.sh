#!/usr/bin/env bash

use_sed="true"
server="${1}"
backup_dir="${2}"
dirs_to_update=("manifest.json" "config-overrides" "config" "defaultconfigs" "kubejs" "mods")

if
  [ -z "$server" ] &&
    [ -z "$backup_dir" ]
then
  echo "This script must be called with the server folder and backup directory, in that order. eg ./updateMoni.sh Monifactory-Server backup"
  exit 1
elif [ -z "$server" ]; then
  echo 1>&2 "$0: server to update not provided"
  exit 2
elif [ -z "$backup_dir" ]; then
  echo 1>&2 "$0: backup directory not provided"
  exit 2
fi

if [ "$(jq --version)" ] &>/dev/null; then
  use_sed="false"
fi

if [ "${use_sed}" = "true" ]; then
  is_monifactory_server=false
  [ "$(cat ${server}/manifest.json 2>/dev/null | sed -En 's/[ \t]*"name"[ \t]*:[ \t]*"(.+)".*/\1/p')" = "Monifactory" ] && is_monifactory_server=true
else
  is_monifactory_server=false
  [ "$(cat ${server}/manifest.json 2>/dev/null | jq -r '.name')" = "Monifactory" ] && is_monifactory_server=true
fi

if [ "${is_monifactory_server}" = "false" ]; then
  echo 1>&2 "Could not find server at ${server_dir}/${server}"
  exit 2
fi

curl -o /tmp/moni-json -L https://api.github.com/repos/ThePansmith/Monifactory/releases/latest 2>/dev/null || {
  echo 1>&2 "failed to connect to Github to get latest release information"
  exit 1
}

if [ "${use_sed}" = "true" ]; then
  url="$(cat /tmp/moni-json | sed -En 's/[ \t]*"browser_download_url"[ \t]*:[ \t]*"(.+server.zip)".*/\1/p')"
else
  url=$(cat /tmp/moni-json | jq -r '.assets[] | select(.name | endswith("server.zip")) | .browser_download_url')
fi

if [ "${use_sed}" = "true" ]; then
  new_version="$(cat /tmp/moni-json | sed -En 's/[ \t]*"tag_name"[ \t]*:[ \t]*"(.+)".*/\1/p')"
else
  new_version=$(cat /tmp/moni-json | jq -r '.tag_name')
fi

if [ "${use_sed}" = "true" ]; then
  current_version="$(cat ${server}/manifest.json | sed -En 's/[ \t]*"version"[ \t]*:[ \t]*"(.+)".*/\1/p' | sed -n 2p)"
else
  current_version=$(cat ${server}/manifest.json | jq -r '.version')
fi

if [ "$new_version" = "$current_version" ]; then
  echo 1>&2 "Server is already up-to-date"
  exit 1
fi

echo "Updating from ${current_version} to ${new_version}"

echo "Creating backup"
cp -r "${server}" "${backup_dir}/${current_version}-Backup" || {
  echo 1>&2 "failed to create backup, check backup directory is correct and not full"
  exit 1
}
echo "Backup created at ${backup_dir}/${current_version}-Backup"

echo
echo "Downloading new server files from ${url}"
echo

curl -o /tmp/new-moni.zip -L "${url}"

echo
echo "Updating files"

unzip -q /tmp/new-moni.zip -d /tmp/new-moni

cd "${server}"
rm -r "${dirs_to_update[@]}"

cd /tmp/new-moni
mv overrides/* ./
mv "${dirs_to_update[@]}" "${server}/"

echo "Updating finished"
echo
echo "Cleaning up"

cd /tmp
rm -r moni-json new-moni*
