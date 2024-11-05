#!/bin/bash
set -x
#set -e

DISK_TO_PGP='DISK NAME'
KEY_TO_PGP='PGP KEY'
RCLONE_DEST='RCLONE DESTINATION PATH'

SCRIPTDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd $SCRIPTDIR

rclone delete enc_storage_box: --include '*.{bak,xml,gpg}'

for vm in $(virsh list --all --name) ; do
  disk_name=$(virsh dumpxml "$vm" | xmlstarlet sel -t -m '/domain/devices/disk' -m 'source/@*' -v '.' -n | head -1)
  echo "$vm -> $disk_name"

  virsh dumpxml $vm > "$vm.xml"
  rclone move "$vm.xml" $RCLONE_DEST 
  virsh backup-begin $vm
  time virsh event $vm --event block-job
  virsh domjobinfo $vm --completed

  backup_disk_name=$(ls -rt $disk_name.* | tail -1)

  if [[ $backup_disk_name == *"$DISK_TO_PGP"* ]]; then
  	# gpg --import private.gpg && gpg --output new_file_name --decrypt encrypted_file # to decrypt
  	time gpg -z 9 --batch --yes --trust-model always --output "$backup_disk_name.gpg" --encrypt --recipient $KEY_TO_PGP "$backup_disk_name" 
  	ls -lh `dirname "$disk_name"`
	rm $backup_disk_name
	time rclone move "$backup_disk_name.gpg" $RCLONE_DEST 
  else
  	mv $backup_disk_name "$backup_disk_name.bak" 	
	time rclone move "$backup_disk_name.bak" $RCLONE_DEST 
  fi

done
