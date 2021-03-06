#!/bin/bash

# write_usb.sh
#
# Copy usb-hdd image to USB device and fill rest of space with ext3 partition.

# Set the defaults
device=/dev/sdf
image=binary.img

# Set the PATH
PATH=/sbin:$PATH

# Check for needed utilities
for i in parted dd mkfs.ext3 sudo awk sed mount umount; do \
   which $i >/dev/null 
   if [ "$?" != 0 ]; then echo "Can't find $i, aborting..."; exit 1; fi
done

# Prompt for device
echo -n "Enter device name to wipe: ($device) "
read new_device
[ -n "$new_device" ] && device="$new_device"
if [ ! -b "$device" ]; then \
   echo "$device is not a valid block device, aborting..."
   exit 1
fi 

# Prompt for image file
echo -n "Enter filename of USB image: ($image) "
read new_image
[ -n "$new_image" ] && image="$new_image"
if [ ! -r "$image" ]; then \
   echo "Can't read $image, aborting..."
   exit 1
fi

# Set some command abbreviations
parted_print="parted $device --script print"
parted_mkpart="parted $device --script -- mkpart primary"
parted_set="parted $device --script set"

# Check to make sure we can wipe this disk
sudo $parted_print
echo -n "Are you sure you want to wipe this disk? (y/n) "
read ANS
[ "$ANS" != "y" ] && exit 0

unmount_all() {
   # Unmount partitions if any are mounted
   for i in `mount | grep "$1" | awk '{ print $1 }'`; do \
      echo "Unmounting ${i}..."
      sudo umount "$i" || return 1
   done
}

# Unmount all partitions of usb device if any are already mounted
unmount_all "$device" || exit 1

# Copy the usb image to usb device
sudo dd if="$image" of="$device" bs=1M || exit 1

# Calculate the start position of new partition in MB.
end=`sudo $parted_print | awk '/^[ ]*1/ { print $3 }' | sed 's/MB//g'`
let start=end+1

# Use -1 for end position to take all remaining space
end=-1

# Create the new partition
sudo $parted_mkpart $start $end || exit 1

# Set the bootable flag for partition 1
sudo $parted_set 1 boot on || exit 1

# Allow some time for partitions to automount, if system is set to do that
sleep 5

# Unmount all partitions of usb device if any are already mounted
unmount_all "$device" || exit 1

# Format the new partition and print new table
sudo mkfs.ext3 -L persistence "${device}2" 
sudo $parted_print
