#!/bin/bash

log_info() {
  echo "[INFO] $1"
}

log_error() {
  echo "[ERROR] $1"
}

log_exec() {
  echo "[EXEC] $1"
}

usage() {
  echo "Usage: $0 --device <usb-device> [--id <container-id>] [--storage <storage-id>] [--drymode]"
  exit 1
}

dry_mode=false

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    --device)
      usb_device="$2"
      shift
      shift
      ;;
    --id)
      container_id="$2"
      shift
      shift
      ;;
    --storage)
      storage_id="$2"
      shift
      shift
      ;;
    --drymode)
      dry_mode=true
      shift
      ;;
    *)
      # Unknown option
      usage
      ;;
  esac
done

if [ -z "$usb_device" ]; then
  log_error "USB device not specified."
  usage
fi

# Use default container ID if not provided
if [ -z "$container_id" ]; then
  container_id="100"
fi

# Use default storage ID if not provided
if [ -z "$storage_id" ]; then
  storage_id="usb-drive"
fi

usb_mount_point="/mnt/$storage_id"

# Make sure the USB device is not already mounted
if grep -qs "$usb_mount_point" /proc/mounts; then
  log_error "$usb_mount_point is already mounted."
  exit 1
fi

if [ "$dry_mode" = true ]; then
  log_info "Running in dry mode. No actual operations will be performed."
fi

if [ "$dry_mode" = true ]; then
  log_info "Mounting USB device $usb_device to $usb_mount_point (Dry mode, not executed)."
  log_exec "mount $usb_device $usb_mount_point (Dry mode, not executed)."
else
  log_info "Mounting USB device $usb_device to $usb_mount_point."
  log_exec "mount $usb_device $usb_mount_point"
  mount "$usb_device" "$usb_mount_point"
fi

# Add the mount point as a storage in Proxmox
if [ "$dry_mode" = true ]; then
  log_info "Adding storage $storage_id from $usb_mount_point to Proxmox (Dry mode, not executed)."
  log_exec "pvesm add dir $storage_id --path $usb_mount_point --content backup (Dry mode, not executed)."
else
  log_info "Adding storage $storage_id from $usb_mount_point to Proxmox."
  log_exec "pvesm add dir $storage_id --path $usb_mount_point --content backup"
  pvesm add dir "$storage_id" --path "$usb_mount_point" --content backup
fi

# Run the backup for the specified container ID to the USB drive
if [ "$dry_mode" = true ]; then
  log_info "Running backup for container ID $container_id to $storage_id (Dry mode, not executed)."
  log_exec "vzdump $container_id --mode snapshot --storage $storage_id (Dry mode, not executed)."
else
  log_info "Running backup for container ID $container_id to $storage_id."
  log_exec "vzdump $container_id --mode snapshot --storage $storage_id"
  vzdump "$container_id" --mode snapshot --storage "$storage_id"
fi

# Remove the storage from Proxmox (optional, to avoid cluttering the GUI)
if [ "$dry_mode" = true ]; then
  log_info "Removing storage $storage_id from Proxmox (Dry mode, not executed)."
  log_exec "pvesm remove $storage_id (Dry mode, not executed)."
else
  log_info "Removing storage $storage_id from Proxmox."
  log_exec "pvesm remove $storage_id"
  pvesm remove "$storage_id"
fi

# Unmount the USB drive
if [ "$dry_mode" = true ]; then
  log_info "Unmounting USB device $usb_device from $usb_mount_point (Dry mode, not executed)."
  log_exec "umount $usb_mount_point (Dry mode, not executed)."
else
  log_info "Unmounting USB device $usb_device from $usb_mount_point."
  log_exec "umount $usb_mount_point"
  umount "$usb_mount_point"
fi

if [ "$dry_mode" = true ]; then
  log_info "Dry mode execution completed. No actual operations were performed."
fi
