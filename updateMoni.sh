#!/usr/bin/env bash

server="${1}"
server_dir="/srv/minecraft"
backup_dir="/srv/minecraft/backups"
dirs_to_update=("manifest.json" "config-overrides" "config" "defaultconfigs" "kubejs" "mods")

if [ -z "$server" ]; then
  echo 1>&2 "$0: server to update not provided"
  exit 2
fi

if [ ! -d "${server_dir}/${server}" ] || \
   [ ! -f "${server_dir}/${server}/manifest.json" ] || \
   [ "$(cat ${server_dir}/${server}/manifest.json | jq -r '.name')" != "Monifactory" ]; 
then
  echo 1>&2 "$0: Could not find server at ${server_dir}/${server}"
  exit 2
fi

curl -o /tmp/moni-json -L https://api.github.com/repos/ThePansmith/Monifactory/releases/latest 2>/dev/null
url=`cat /tmp/moni-json | jq -r '.assets[] | select(.name | endswith("server.zip")) | .browser_download_url'`
new_version=`cat /tmp/moni-json | jq -r '.tag_name'`
current_version=`cat ${server_dir}/${server}/manifest.json | jq -r '.version'`
new_server="Monifactory-${new_version}"

if [ "$new_version" = "$current_version" ]; then
  echo 1>&2 "$0: Server is already up-to-date"
  exit 1
fi

echo "Creating backup"
cp -r "${server_dir}/${server}" "${backup_dir}/${server}-Backup"
echo "Backup created at ${backup_dir}/${server}-Backup"

mv "${server_dir}/${server}" "${server_dir}/${new_server}" 

echo
echo "Downloading new server files from ${url}"
echo

curl -o /tmp/new-moni.zip -L "${url}"

echo
echo "Updating files"

unzip -q /tmp/new-moni.zip -d /tmp/new-moni

cd "${server_dir}/${new_server}"
rm -r "${dirs_to_update[@]}"

cd /tmp/new-moni
mv overrides/* ./
mv "${dirs_to_update[@]}" "${server_dir}/${new_server}/"

echo "Updating finished"
echo
echo "Cleaning up"

cd /tmp
rm -r moni-json new-moni*
