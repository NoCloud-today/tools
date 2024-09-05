#!/bin/bash
set -x
set -e

SCRIPTDIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd $SCRIPTDIR

BACKUPS_DIR="./kvm_backup"

for vm in $(virsh list --all --name) ; do
  disk_name=$(virsh dumpxml "$vm" | xmlstarlet sel -t -m '/domain/devices/disk' -m 'source/@*' -v '.' -n | head -1)
  echo "$vm -> $disk_name"
  VM_BACKUP_DIR="$BACKUPS_DIR/$vm"
  mkdir -p $VM_BACKUP_DIR

  virsh dumpxml $vm > "$VM_BACKUP_DIR/$vm.xml"
  virsh backup-begin $vm
  virsh event $vm --event block-job
  virsh domjobinfo $vm --completed

  backup_disk_name=$(ls -rt $disk_name.* | tail -1)
  time bzip2 -9 $backup_disk_name
  mv $backup_disk_name.bz2 $VM_BACKUP_DIR/

done
