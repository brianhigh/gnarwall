# Recipe: Building a GnarWall Filtering Bridge from Debian's Web-based Live Builder

Problem:  You want to run the [NDC LFW](https://staff.washington.edu/corey/fw/) scripts for your filtering bridge firewall, but you do not want to use [Gibraltar](http://www.gibraltar.at/).  Instead, you want something you can customize, run solely from your USB stick, and update when you want to.

Solution:  [Live-Systems.org](http://cgi.build.live-systems.org/cgi-bin/live-build) has a [web-based live build web application](http://cgi.build.live-systems.org/cgi-bin/live-build) which can build your image in a few minutes, with many customization options.


## GnarWall Script Files

Download the latest [GnarWall scripts](https://github.com/brianhigh/gnarwall/archive/master.zip) we have shared for this project.

You can extract them on a Linux system with:

```
$ unzip gnarwall-master.zip
```


## Debian Live Disk Image

To get a live disk image, you can build your own, with either the web-based live-build or command-line utilities, or you can download one made especially for use with GnarWall. All three methods are presented below.

### Web-based live-build

Go to: http://cgi.build.live-systems.org/cgi-bin/live-build

Fill out the web form`*` as shown in this example configuration:

```
Email Address:  you@example.com

[ Standard options ]
--binary-images:    iso-hybrid
--distribution:     jesse
--packages-lists:   standard
--packages:         dialog apt debconf parted exim4 mailutils 
                    sudo snmp snmpd openssh-client openssh-server ntp 
                    ebtables bridge-utils logwatch iputils-ping logcheck 
                    netbase update-inetd tcpd dhcpcd5 rsyslog rsync 
                    patch rdate genext2fs vim-tiny nano locales coreutils

[ Advanced chroot options ]
--linux-flavours:   686-pae
--security:         true

[ Advanced binary options ]
--apt-indices:      false
--bootappend-live:  noautologin toram ip=frommedia quickreboot nofast 
                    noprompt boot=live config quiet splash persistence
--iso-application:  GnarWall
--memtest:          none
```

(`*` = The options in the form change as the Debian Live project evolves so adapt accordingly.)

You will want to use your own email address, of course. For "--linux-flavours", you might prefer 
something like 486 for older systems (e.g., for older processors such as 486, Pentium I, etc.).


#### Downloading the Image

After a few minutes you will be able to download your image.

The Live Build web application will show you a link to download your files. You will get an email when they are ready.

Download the files and check the MD5 sum of the image against the MD5 sum listed in the md5sum file.

You may also choose to save the other files for reference.  (The build system will include the configuration files in the build folder.)


### Command-line live-build utilities

Alternatively, if you have a Linux system, you can also build the image yourself. Here is an example using [lb](https://packages.debian.org/jessie/live-build) version 4.x running on Debian "Jesse":

```
$ sudo apt-get install live-build debootstrap syslinux squashfs-tools genisoimage rsync

$ unzip gnarwall-master.zip
$ mkdir -p live-build/config/bootloaders/isolinux/
$ cd live-build

$ echo "dialog apt debconf parted exim4 mailutils sudo snmp snmpd openssh-client openssh-server ntp ebtables bridge-utils logwatch iputils-ping logcheck netbase update-inetd tcpd rsyslog rsync patch rdate genext2fs vim-tiny nano locales user-setup coreutils" > config/package-lists/minimal.list.chroot

$ sudo lb config -a i386 -k 686-pae -b iso-hybrid --bootstrap debootstrap --debootstrap-options "--variant=minbase" --security true --apt-indices false --iso-application GnarWall --memtest none --source false --bootloader syslinux --bootappend-live "noautologin toram ip=frommedia quickreboot nofast noprompt boot=live config quiet splash persistence"

$ sudo lb clean --purge  # Only needed if you are rebuilding after a previous attempt... 
$ sudo lb build
```

If you wish to include a Debian Live installer with your image, then add "dhcpcd5" to your list of packages 
and add this string to your `lb config` line: --debian-installer live. 

You should find your binary image file in the current working directory with the filename: `live-image-i386.hybrid.iso`. Elsewhere in this and other GnarWall documentation, we refer to this file as `binary.img`, so you might want to rename your file to `binary.img`.

### Download custom images

We have uploaded a few sample binary images made like this to our [downloads page](https://sites.google.com/site/gnarwallproject/file-cabinet).  
You can use one of these if you have trouble making one your own, or simply want to get started right away.


## Installing the Image

You can now copy the `binary.img` file to your USB stick.  Not a regular "drag and drop" sort of copy, though.  You need to write this image to the USB device with a utility like `dd` (though there are other ways that will work).

Use a USB flash memory stick of at least 1 GB.  The image is only a few hundred MB, but you will want space for your persistent files (log and configuration files).

You will lose any data already on the USB device, so backup anything that you would want to keep.

When you connect your USB device to a Linux system, you can check `dmesg` or the `messages` or `syslog` files to 
see the device name it was provided. Make sure no partitions on the USB device are already mounted, but do not 
"eject" it.

### Installing the "hard way" (manually)

Here is how you can write the image to the USB stick, assuming it is assigned to /dev/sdb:

```
$ sudo dd if=binary.img of=/dev/sdb bs=1M
```

This would also work:

```
$ sudo cp binary.img /dev/sdb
```

You will likely want to add a persistent (snapshot) partition.  You can do this with fdisk and mkfs.ext3

```
$ sudo fdisk /dev/sdb
n (enter)
p (enter)
2 (enter)
(enter)
(enter)
w (enter)
```

This is to make a (n) new (p) primary partition, number (2), starting at the next available cylinder (the default) and ending at the last cylinder (the default), then (w) write changes and exit the fdisk utility.


#### Formatting the Partition

```
$ sudo mkfs.ext3 -L live-sn /dev/sdb2
```

This adds the live-sn label which tells Debian Live to use it for persistent live-snapshots.

If you use some other labels supported by live-initramfs, you can get other behavior, like live real-time read-write functionality.  (We opted for the snapshot option to minimize disk activity.)


### Installing the "easy way" (using a script)

All of steps in this section (Installing the Image and Formatting the Partition) can be accomplished by running this bash shell script: [write_usb.sh](https://github.com/brianhigh/gnarwall/blob/master/disk/write_usb.sh).

### Persistence

While we have created a persistent partition in the previous section, we need to add a configuration file to enable it.

```
$ unzip master.zip
$ mkdir sdb2
$ sudo mount /dev/sdb2 sdb2
$ sudo cp gnarwall-master/system/persistence.conf sdb2/
$ sudo sync
$ sudo umount /dev/sdb2
```

### Further Customization

You may also wish to add additional files to the persistent partition or customize your custom image. Since the 
binary image partition is read-only, changes to these configuration files are made before building the image 
with `lb build`.

You can add a custom [splash image](https://github.com/brianhigh/gnarwall/blob/master/system/isolinux/splash.png) 
or set a boot-menu countdown timer, for example. See our isolinux 
[patch files](https://github.com/brianhigh/gnarwall/tree/master/system/isolinux) for sample modifications.

For example, here is how you could patch the isolinux menu files for our custom menu preferences and replace 
the default splash image (SVG) with our custom image (PNG):

```
$ unzip master.zip
$ mkdir -p live-build/config/bootloaders/isolinux/
$ cp gnarwall-master/system/isolinux/isolinux-with-installer.patch live-build/config/bootloaders/isolinux/
$ cp gnarwall-master/system/isolinux/splash.png live-build/config/bootloaders/isolinux/
$ cd live-build/
$ echo "[...]" > config/package-lists/minimal.list.chroot  # Use an actual package list in place of [...]
$ lb config [...]        # Use whatever options you like in place of [...], as in the "lb" examples above
$ cd config/bootloaders/isolinux/
$ rm -f splash.svg
$ patch -l -p0 < isolinux-with-installer.patch
$ cd ../../../
$ sudo lb clean --purge  # Only needed if you are rebuilding after a previous attempt... 
$ sudo lb build          # To make your custom iso image
```

This will remove the "advanced" menu options, move the menu to avoid overlap with the splash image, and set a 
10 second timout so the system can boot without any user interaction. It will still include the menu choices 
for the live installer.

`Note: More suggestions are mentioned in the doc/INSTALL file included with the main GnarWall script archive (gnarwall-master.zip).  Further, it includes a complete step-by-step installation guide for using all of the scripts and patches mentioned in this tutorial.`

You can also place your other system files on the USB stick's persistent partition. We extract the GnarWall 
script archive and copy to the mounted ext3 partition:

```
$ unzip gnarwall-master.zip
$ mkdir sdb2
$ sudo mount /dev/sdb2 sdb2
```

Now you can place your NDC LFW `tables` file in `usr/local/sbin` and copy the scripts:

```
$ sudo cp -R gnarwall-master/usr sdb2/
```

And, likewise, you can place your NDC LFW `interfaces` file in `etc/network` and copy to the `ext3` partition:

```
$ sudo cp -R gnarwall-master/etc sdb2/
```

If your files were generated from the NDC LFW website, you may need to modify them to work with GnarWall. This is covered next.


## Updating the NDC LFW Generated Scripts

Since things have changed a bit in the Linux world since the 2.4 kernel days (the kernel version that the NDC LFW scripts were designed for), we need to make some changes to these files.

We have done some testing with the [Variation 4](https://staff.washington.edu/corey/fw/variations.html#variation4) 
(filtering bridge) and [Variation e10](https://staff.washington.edu/corey/fw/fw.cgi?variation=e10) (logical 
firewall with NAT) scripts.  We have a 
[bash script](https://github.com/brianhigh/gnarwall/blob/master/convert/lfw_fix_v4.sh) and 
[patch](https://github.com/brianhigh/gnarwall/blob/master/convert/tables_v4.patch) to update Variation 4 and 
Variation e10 interfaces and tables file.  Please read the comments in the script carefully and modify as needed. 
Also, look through the patch file to see what is actually changing.

These two files (lfw\_fix\_v4.sh and tables\_v4.patch) can be downloaded [here](https://github.com/brianhigh/gnarwall/archive/master.zip).  After you extract them from the archive, you will want to place them both in the same folder with your tables and interfaces files.  Then you can run the lfw\_fix\_v4.sh bash script.

It should be noted that the `interfaces` file will still need some more fixing to be fully compliant with the [modern Debian way of doing things](http://wiki.debian.org/BridgeNetworkConnections#A.2BAC8-etc.2BAC8-network.2BAC8-interfacesandbridging).


So here is how an updated interfaces script might look for a Variation 4 Filtering Bridge:

```
# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8). Run:
#   /etc/init.d/networking restart
# to execute this file before the next reboot
# Note: each interface must have its own paragraph separated by blank lines

# The loopback interface
auto lo
iface lo inet loopback

iface eth0 inet manual

iface eth1 inet manual

# this is the native IP address of your firewall itself
auto br0
iface br0 inet static
    address 192.168.1.30
    netmask 255.255.255.0
    network 192.168.1.0
    broadcast 192.168.1.255
    gateway 192.168.1.100
    bridge_ports eth0 eth1
    bridge_fd       5
    bridge_hello    2
    bridge_maxage   5
    bridge_stp      on
    
# this is the last line of /etc/network/interfaces
```

(That file can be found in the GnarWall package as interfaces.v4.  You will need to edit it manually.)

Similarly, this is an example `interfaces` file for a Variation e10 logical firewall:

```
# /etc/network/interfaces -- configuration file for ifup(8), ifdown(8). Run:
#   /etc/init.d/networking restart
# to execute this file before the next reboot
# Note: each interface must have its own paragraph separated by blank lines

# The loopback interface
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 192.168.1.1
    netmask 255.255.255.0
    network 192.168.1.0
    broadcast 192.168.1.255
    gateway 192.168.1.100

auto eth0:1
iface eth0:1 inet static
    address 10.168.1.1
    netmask 255.255.255.0
    network 10.168.1.0
    broadcast 10.168.1.255

# this is the last line of /etc/network/interfaces
```

(In the GnarWall package as interfaces.ve10.)

And this iptables start script could be saved as: /etc/network/if-pre-up.d/iptables

```
#! /bin/sh
# Reload the firewall rules when an interface comes up

set -e

# Don't bother to start iptables when lo is configured.
if [ "$IFACE" = lo ]; then
	exit 0
fi

# Only run from ifup.
if [ "$MODE" != start ]; then
	exit 0
fi

# Is /usr mounted?
if [ ! -e /usr/local/sbin/tables ]; then
	exit 0
fi

/usr/local/sbin/tables >/dev/null 2>&1 || true

exit 0
```


We will update this page soon with a revised conversion script.  Until then, this version will work well enough for testing.  Of course, ideally, we will want to update the NDC LFW generator application, so no special conversion scripts will be needed, but that will have to wait a bit...

## Suggested Additional Files

We have found it useful to place the following files in the persistent partition:

```
etc/resolv.conf
etc/timezone
etc/hostname
etc/mailname
etc/hosts
etc/ntp.conf
```

... and anything else you might have customized, such as (ip)tables and interfaces.  It all depends on what you are trying to do, and what has already been configured using the boot parameters (like hostname or timezone).

You can also use a configuration script, much like [gnarwall\_setup.sh](https://github.com/brianhigh/gnarwall/blob/master/system/usr/local/sbin/gnarwall_setup.sh) 
included in the GnarWall package, to make these common etc/ files.  Be sure to set the first group of configuration variables.  (TIP: Run this script from within the _live_ system.)

It only creates configuration files if they do not already exist.  Most of the script is not even run if a placeholder file (/etc/gnarwall/configured) already exists.  The placeholder file is created the first time the script is run.  The time is set with rdate.

We run our configuration script from a line in our /etc/rc.local file:

```
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.

/usr/local/sbin/gnarwall_setup.sh

exit 0
```

To do a clean configuration reset, we run:

```
$ sudo /usr/local/sbin/gnarwall-reset.sh
$ sudo /usr/local/sbin/gnarwall-setup.sh
```

Where, /usr/local/sbin/gnarwall-reset.sh contains:

```
#!/bin/bash

# gnarwall-reset.sh
#
# Remove configuration files so they will be recreated by
# gnarwall_setup.sh

# List of filenames
conf_files=(
'/etc/resolv.conf'
'/etc/timezone'
'/etc/hostname'
'/etc/mailname'
'/etc/hosts'
'/etc/ntp.conf'
'/etc/default/locale'
'/etc/locale.gen'
'/etc/network/if-pre-up.d/disable_ipv6'
'/etc/gnarwall/configured'
)

rm -f "${conf_files[@]}" 2>/dev/null
```


All of these configuration scripts are secured with:

```
$ sudo chown root /etc/rc.local /usr/local/sbin/*
$ sudo chmod 0700 /etc/rc.local /usr/local/sbin/*
```

If you prefer, you can simply do all of the customization manually after you boot the USB stick.  Your changes will be saved to the persistent partition when you reboot.

But the very first thing you should do when you log into the live system (username=user, password=live) is change the root password from the default empty password (no password)!  If you do not want to keep the default `user` account on the system, then log in as root and remove the default live user account. 

```
# userdel -f -r user
```

Otherwise be sure and change that password as well.

You can also install and remove software with `apt-get` and `dpkg` -- from within the live system.  Just remember that package caches can fill your persistent partition fairly quickly, so run the associated clean command before restarting or snapshotting.

For packages you included in your live build parameters, such as tzdata or openssh-server, you may want to run dpkg-reconfigure on them once to make sure they are configured they way you want them to be.


## Give it a try

Please give this a try and let us know how it goes.  You might like to read the [INSTALL](https://github.com/brianhigh/gnarwall/blob/master/doc/INSTALL) file for more specific instructions. Also, any feedback on this recipe will be very helpful.


## License

This tutorial and the code listed within is licensed under the [GNU General Public License](http://www.gnu.org/licenses/gpl.html):

```
GnarWall: Logical Firewall and Filtering Bridge
Copyright © University of Washington

This file is part of GnarWall.

GnarWall is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

GnarWall is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GnarWall.  If not, see <http://www.gnu.org/licenses/>.
```
