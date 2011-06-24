#!/bin/bash

# write_usb.sh
#
# Copy usb-hdd image to USB device and fill rest of space with ext3 partition.

# Set the defaults
DEV=/dev/sdf
IMG=binary.img

# Set the PATH
PATH=/sbin:$PATH

# Check for needed utilities
for i in parted dd mkfs.ext3 sudo awk sed mount umount; do \
   which $i >/dev/null 
   if [ "$?" != 0 ]; then echo "Can't find $i, aborting..."; exit 1; fi
done

# Prompt for device
echo -n "Enter device name to wipe: ($DEV) "
read NEWDEV
[ -n "$NEWDEV" ] && DEV="$NEWDEV"
if [ ! -b "$DEV" ]; then \
   echo "$DEV is not a valid block device, aborting..."
   exit 1
fi 

# Prompt for image file
echo -n "Enter filename of USB image: ($IMG) "
read NEWIMG
[ -n "$NEWIMG" ] && IMG="$NEWIMG"
if [ ! -r "$IMG" ]; then \
   echo "Can't read $IMG, aborting..."
   exit 1
fi

# Set some command abbreviations
PTD_PRN="parted ${DEV} --script print"
PTD_MKP="parted ${DEV} --script -- mkpart primary"
PTD_SET="parted ${DEV} --script set"

# Check to make sure we can wipe this disk
sudo $PTD_PRN
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
unmount_all "$DEV" || exit 1

# Copy the usb image to usb device
sudo dd if="$IMG" of="${DEV}" bs=1M || exit 1

# Calculate the start position of new partition in MB.
END=`sudo $PTD_PRN | awk '/^[ ]*1/ { print $3 }' | sed 's/MB//g'`
let START=END+1

# Use -1 for end position to take all remaining space
END=-1

# Create the new partition
sudo $PTD_MKP $START $END || exit 1

# Set the bootable flag for partition 1
sudo $PTD_SET 1 boot on || exit 1

# Allow some time for partitions to automount, if system is set to do that
sleep 5

# Unmount all partitions of usb device if any are already mounted
unmount_all "$DEV" || exit 1

# Format the new partition and print new table
sudo mkfs.ext3 -L live-sn "${DEV}2" 
sudo $PTD_PRN
