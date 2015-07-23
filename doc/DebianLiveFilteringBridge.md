# Recipe: Building a GnarWall Filtering Bridge from Debian's Web-based Live Builder

Problem:  You want to run the [NDC LFW](https://staff.washington.edu/corey/fw/) scripts for your filtering bridge firewall, but you do not want to use [Gibraltar](http://www.gibraltar.at/).  Instead, you want something you can customize, run solely from your USB stick, and update when you want to.

Solution:  [Live-Systems.org](http://cgi.build.live-systems.org/cgi-bin/live-build) has a [web-based live build web application](http://cgi.build.live-systems.org/cgi-bin/live-build) which can build your image in a few minutes, with many customization options.


## GnarWall Script Files

Download the latest [GnarWall scripts](https://github.com/brianhigh/gnarwall/archive/master.zip) we have shared for this project.

You can extract them on a Linux system with:

```
$ unzip master.zip
```


## Debian Live Disk Image

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
--linux-flavours:   686
--security:         true

[ Advanced binary options ]
--apt-indices:      false
--bootappend-live:  noautologin toram ip=frommedia quickreboot nofast 
                    noprompt boot=live config quiet splash persistence
--iso-application:  GnarWall
--memtest:          none
```

(`*` = The options in the form change as the Debian Live project evolves so adapt accordingly.)

You will want to use your own email address, of course.


### Downloading the Image

After a few minutes you will be able to download your image.

The Live Build web application will show you a link to download your files. You will get an email when they are ready.

Download the files and check the MD5 sum of the image against the MD5 sum listed in the md5sum file.

You may also choose to save the other files for reference.  (The build system will include the configuration files in the build folder.)


### Alternate Method of Building the Image

Alternatively, if you have a Debian "Jesse" system, you can also build the image yourself. Here is an example using [lb](https://packages.debian.org/jessie/live-build) version 4.x:

```
$ sudo apt-get install live-build debootstrap syslinux squashfs-tools genisoimage rsync

$ mkdir live-build
$ cd live-build
$ mkdir -p config/package-lists/

$ echo "dialog apt debconf parted exim4 mailutils sudo snmp snmpd openssh-client openssh-server ntp ebtables bridge-utils logwatch iputils-ping logcheck netbase update-inetd tcpd dhcpcd5 rsyslog rsync patch rdate genext2fs vim-tiny nano locales user-setup coreutils" > config/package-lists/minimal.list.chroot

$ sudo lb config -a i386 -k 486 -b iso-hybrid --bootstrap debootstrap --debootstrap-options "--variant=minbase" --security true --apt-indices false --iso-application GnarWall --memtest none --source false --bootloader syslinux --bootappend-live "noautologin toram ip=frommedia quickreboot nofast noprompt boot=live config quiet splash persistence"

$ sudo lb build
```
You should place your binary image file in the current working directory with the filename: `live-image-i386.hybrid.iso`. Elsewhere in this and other GnarWall documentation, we refer to this file as `binary.img`.

We have uploaded a binary image made like this on our [downloads page](https://sites.google.com/site/gnarwallproject/file-cabinet).  You can use this if you have trouble making your own, or simply want to get started right away.


### Installing the Image

You can now copy the binary.img file to your USB stick.  Not a regular "drag and drop" sort of copy, though.  You need to write this image to the USB device with a utility like `dd`.

Use a USB flash memory stick of at least 1 GB.  The image is less than 150 MB, but you will want space for your persistent files (log and configuration files).

You will lose any data already on the USB device, so backup anything that you would want to keep.

When you connect your USB device to a Linux system, you can check dmesg to see the device name it was provided.

Here is how you can write the image to the USB stick, assuming it is assigned to /dev/sdb:

```
$ sudo dd if=binary.img of=/dev/sdb bs=1M
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


### Formatting the Partition

```
$ sudo mkfs.ext3 -L live-sn /dev/sdb2
```

This adds the live-sn label which tells Debian Live to use it for persistent live-snapshots.

If you use some other labels supported by live-initramfs, you can get other behavior, like live real-time read-write functionality.  (We opted for the snapshot option to minimize disk activity.)


### Automating the Disk Preparation

All of steps in this section (Installing the Image and Formatting the Partition) can be accomplished by running this bash shell script:

```
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
sudo mkfs.ext3 -L persistent "${DEV}2" 
sudo $PTD_PRN
```

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

You may also wish to add new files or edit the isolinux configuration files in the USB image. Since the binary 
image partition is read-only, changes to these configuration files are made before building the image with `lb build`.

You can add a custom [splash image](https://github.com/brianhigh/gnarwall/blob/master/system/isolinux/splash.png) 
or set a boot-menu countdown timer, for example. See [this patch file](https://github.com/brianhigh/gnarwall/blob/master/system/isolinux/isolinux.patch) for sample modifications.

`Note: More suggestions are mentioned in the doc/INSTALL file included with the main GnarWall script archive (gnarwall_*.tgz).  Further, it includes a complete step-by-step installation guide for using all of the scripts and patches mentioned in this tutorial.`

You can also place your other system files on the USB stick's persistent partition. We extract the GnarWall script archive and copy to the mounted ext3 partition:

```
$ unzip master.zip
$ mkdir sdb2
$ sudo mount /dev/sdb2 sdb2
```

Now you can place your NDC LFW tables file in usr/local/sbin and copy the scripts:

```
$ sudo cp -R gnarwall-master/usr sdb2/
```

And, likewise, you can place your NDC LFW interfaces file in etc/network and copy to the ext3 partition:

```
$ sudo cp -R gnarwall-master/etc sdb2/
```

If your files were generated from the NDC LFW website, you may need to modify them to work with GnarWall. This is covered next.


## Updating the NDC LFW Generated Scripts

Since things have changed a bit in the Linux world since the 2.4 kernel days (the kernel version that the NDC LFW scripts were designed for), we need to make some changes to these files.

We have done some testing with the [Variation 4](https://staff.washington.edu/corey/fw/variations.html#variation4) (filtering bridge) and [Variation e10](https://staff.washington.edu/corey/fw/fw.cgi?variation=e10) (logical firewall with NAT) scripts.  We have a bash script and patch (below) to update Variation 4 and Variation e10 interfaces and tables file.  Please read the comments in the script carefully and modify as needed.  Also, look through the patch file to see what is actually changing.

lfw\_fix\_v4.sh:


```
#!/bin/bash

# lfw_fix_v4.sh
#
# This script (and patch file) will adapt Corey Satten's Variation #4
# NDC LFW scripts for use with Debian Live (Lenny and newer) and other
# modern Debian-based Linux distributions. 
#
# DANGER: This has NOT been widely tested.  USE AT YOUR OWN RISK!
#
# NOTE: This will work only for 2-NIC configurations where eth0 is the
# "outside NIC" and eth1 is the "inside NIC".  If yours are reversed,
# then modify the patch file accordingly before you run this script.
#
# For more NDC LFW information: http://staff.washington.edu/corey/fw/ 
# Debian Live Builder: http://live-build.debian.net/cgi-bin/live-build 

# Check for presence of writable tables and interfaces files
if [ ! -w tables ] || [ ! -w interfaces ]; then \
    echo "Can't find or write to tables or interfaces files!"
    exit 1
fi

# Make backups if they are not already present
if [ ! -e tables.old ]; then cp tables tables.old; fi
if [ ! -e interfaces.old ]; then cp interfaces interfaces.old; fi

# Fix deprecated "intrapositioned negation" in rules (--option ! this)
# This avoids a warning starting with iptables 1.4.3+ (Squeeze has 1.4.8+)
# See PARAMETERS in http://ipset.netfilter.org/iptables.man.html
perl -pi -e 's/(-[\w-]+) ! ([^-]+)/! $1 $2/g' tables

# Use new Netfilter "-m physdev --physdev-(in|out) IFACE" sytax
# Where in/out means incoming/outgoing and IFACE is eth0, eth1, etc.
# (The old -i ethN syntax does not work with a bridge [br0] anymore.)
# Required: iptables 1.3.6+ and kernel with physdev match support
# (CONFIG_IP_NF_MATCH_PHYSDEV=m or CONFIG_IP_NF_MATCH_PHYSDEV=y).
patch -l -p0 < tables_v4.patch

# This patch does not modify generated rules from the web form, so warn.
echo "You may need to edit your 'generated' rules for *_PO or *_PI."

# Well, we will attempt to catch the broadcast and multicast rules.
# This will change the O_NIC to O_NIC_PI (outside nic, incoming traffic)
perl -pi -e 's/(--pkt-type (broad|multi)cast \$O_NIC)\b/${1}_PI/g' tables

# Use rsyslog (default log daemon in Debian Lenny+) instead of klogd
perl -pi -e 's/klogd/rsyslog/g' interfaces
```


tables\_v4.patch:


```
*** tables.old	2010-10-25 15:07:26.000000000 -0700
--- tables	2010-10-25 15:13:15.000000000 -0700
***************
*** 1,4 ****
! : # BE SURE THIS IS STILL THE FIRST LINE AFTER YOU PASTE INTO THE TABLES FILE
  #
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11 #
  #
--- 1,4 ----
! #!/bin/bash
  #
  PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/bin/X11 #
  #
***************
*** 68,75 ****
  # 1) adding interface tests to inside/outside packet marking and
  # 2) editing interfaces file to change eth0:1 to eth1 if $ALTER_INTERFACES=1
  case "$TWO_NIC_FIREWALL" in 0|'');; *)
!   O_NIC='-i eth0'	# eth0 is outside NIC
!   I_NIC='-i eth1'	# eth1 is inside  NIC
  esac
  case "$ALTER_INTERFACES" in 0|'');; *)
    (echo 'r /etc/network/interfaces'
--- 69,86 ----
  # 1) adding interface tests to inside/outside packet marking and
  # 2) editing interfaces file to change eth0:1 to eth1 if $ALTER_INTERFACES=1
  case "$TWO_NIC_FIREWALL" in 0|'');; *)
!   OUTSIDE_NIC='eth0'
!   INSIDE_NIC='eth1'
! 
!   O_NIC="-i $OUTSIDE_NIC"
!   I_NIC="-i $INSIDE_NIC"
! 
!   PHYS_DEV='-m physdev --physdev'
! 
!   O_NIC_PO="${PHYS_DEV}-out $OUTSIDE_NIC"
!   O_NIC_PI="${PHYS_DEV}-in $OUTSIDE_NIC"
!   I_NIC_PO="${PHYS_DEV}-out $INSIDE_NIC"
!   I_NIC_PI="${PHYS_DEV}-in $INSIDE_NIC"
  esac
  case "$ALTER_INTERFACES" in 0|'');; *)
    (echo 'r /etc/network/interfaces'
***************
*** 172,178 ****
  
  # mark all outbound client packets from inside LFW with $MK_I
  
! iptables     -t mangle $PRE	       ${I_NIC- -s $I_NET}  -j $MARK $MK_I
  iptables     -t mangle $FWD			-i ppp+     -j $MARK $MK_IP 2>&-
  
  [ $? -eq 0 ] || echo "Note: VPN client rules need a newer OS version" 1>&2
--- 183,189 ----
  
  # mark all outbound client packets from inside LFW with $MK_I
  
! iptables     -t mangle $PRE        ${I_NIC_PI- -s $I_NET}  -j $MARK $MK_I
  iptables     -t mangle $FWD         -i ppp+     -j $MARK $MK_IP 2>&-
  
  [ $? -eq 0 ] || echo "Note: VPN client rules need a newer OS version" 1>&2
***************
*** 184,190 ****
  case "$ACCEPT_ONLY_FROM$O_NIC" in '');; *)	# if accept_from or 2_nic_fw
    NET=${ACCEPT_ONLY_FROM:+"$O_NET"}
    for NET in ${NET:-0.0.0.0/0}; do
!     iptables -t mangle $PRE	       ${O_NIC} -s $NET $MX -j $MARK $MK_X
    done
    MX="-m mark --mark $MK_X/$MK_X"		# redefine $MX test for external
  esac
--- 195,201 ----
  case "$ACCEPT_ONLY_FROM$O_NIC" in '');; *)  # if accept_from or 2_nic_fw
    NET=${ACCEPT_ONLY_FROM:+"$O_NET"}
    for NET in ${NET:-0.0.0.0/0}; do
!     iptables -t mangle $PRE        ${O_NIC_PI} -s $NET $MX -j $MARK $MK_X
    done
    MX="-m mark --mark $MK_X/$MK_X"       # redefine $MX test for external
  esac
```

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

You can also use a configuration script, much like gnarwall\_setup.sh below, to make these common etc/ files.  Be sure to set the first group of configuration variables.  (TIP: Run this script from within the _live_ system.)

```
#!/bin/bash
#
# gnarwall-setup.sh
#
# Configures GnarWall.  Can be run on system startup or manually.

# Configuration variables
host=firewall
domain=mydept.example.com
timezone='America/Los_Angeles'
locale='en_US.UTF-8'
email='admin@example.com'
timeserver=time.example.com
nameserver1=192.168.0.221
nameserver2=192.168.0.222
dns_search_order="$domain example.com"
dis_ipv6=0             # 1=True (to disable ipv6) or 0=False (don't)
bell='none'            # Set to 'none', 'visible', or '' for audible

gnarwall=/etc/gnarwall
gnarwall_conf=$gnarwall/configured

# Create /etc/resolv.conf if it does not already exist
resolv_conf=/etc/resolv.conf

[ -s $resolv_conf ] || cat > $resolv_conf <<EOF
search $dns_search_order
nameserver $nameserver1
nameserver $nameserver2
EOF

# Set time from campus time server
rdate -s $timeserver

# Skip the rest of this script if the system has already been configured
[ -e $gnarwall_conf ] && exit 0

# Create an /etc/ntp.conf if one does not already exist
ntp_conf=/etc/ntp.conf

([ -s $ntp_conf ] && grep -q $timeserver $ntp_conf) || cat > $ntp_conf <<EOF
disable stats
driftfile /var/lib/ntp/drift
broadcastdelay  0.008
server $timeserver
EOF

# Reconfigure timezone
reconfigure=/usr/sbin/dpkg-reconfigure
timezone_conf=/etc/timezone
timezone_package=tzdata
echo "$timezone" > $timezone_conf
$reconfigure -f noninteractive  $timezone_package 2>/dev/null

# Reconfigure resolvconf
$reconfigure -f noninteractive resolvconf 2>/dev/null

# Set mailname and hostname if they have not been already configured
fqdn=${host}.${domain}
mn_conf=/etc/mailname
hn_conf=/etc/hostname
hostname_bin=/bin/hostname
$hostname_bin | grep -q ${host} || $hostname_bin ${host}
([ -s $hn_conf ] && grep -q $fqdn $hn_conf) || echo $fqdn > $hn_conf
([ -s $mn_conf ] && grep -q $fqdn $mn_conf) || echo $fqdn > $mn_conf

# Create /etc/hosts if it does not already exist
hosts_conf=/etc/hosts

[ -s $hosts_conf ] || cat > $hosts_conf <<EOF
127.0.0.1 localhost
127.0.1.1 $fqdn ${hostname}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# Set locale environmental variables
export LANGUAGE="$locale"
export LANG="$locale"
export LC_ALL="$locale"

# Create /etc/default/locale if it does not already contain my locale 
loc=/etc/default/locale
([ -s $loc ] && grep -q "^LANG=$LANG" $loc) || echo LANG=$LANG > $loc

# Create /etc/locale.gen if it does not already contain my locale 
loc_gen_conf=/etc/locale.gen
loc_gen_bin=/usr/sbin/locale-gen
reconfigure=/usr/sbin/dpkg-reconfigure
[ -s $loc_gen_conf ] && grep -q "^$LANG" $loc_gen_conf
if [ $? != 0 ]; then \
   /usr/bin/dpkg-query -W -f='${Status} ${Version}\n' locales > /dev/null
   if [ $? = 0 ]; then \
      rm -f $loc_gen_conf
      $loc_gen_bin "$LANG"
      $reconfigure -u locales
   fi
fi

# Set bell-style in /etc/initrc
inputrc=/etc/inputrc
bell_style_cmd='set bell-style'

if [ -w $inputrc ]; then \
   if [ -z "$bell" ]; then \
      # Comment out all "set bell style" lines to enable default bell
      sed -i "s/^$bell_style_cmd/# $bell_style_cmd/g" $inputrc
   else \
      # Remove all "set bell style" lines and append new one
      sed -i -n "/$bell_style_cmd/!p" $inputrc
      echo "$bell_style_cmd $bell" >> $inputrc
   fi
else
   echo "Can't write to $inputrc!  Can't change bell-style!"
fi

# Modify logcheck ignore rules for ntpd to ignore "time sync status change"
# See:  http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=498992
# This is fixed in logcheck version 1:4.2.6+dfsg-1 on Sat, 26 Dec 2009
lcntp=/etc/logcheck/ignore.d.server/ntp
lcn1='kernel time sync (disabled|enabled)'
lcn2='kernel time sync (enabled|status( change)?)'
([ -s $lcntp ] && grep -qF "$lcn1" $lcntp) && sed -i "s/$lcn1/$lcn2/" $lcntp

# Configure adminstrative email address for logwatch, postmaster, and root.
lc_conf=/etc/logcheck/logcheck.conf
aliases=/etc/aliases
newaliases=/usr/bin/newaliases
[ -s $lc_conf ] && sed -i "s/^\(SENDMAILTO\)=.*$/\1='$email'/" $lc_conf
sed -i "s/^\(postmaster\|logcheck\|root\):.*$/\1:\t$email/" $aliases
[ -x $newaliases ] && $newaliases

# Set defaults for snmpd to log only up to info level
snmpd_conf=/etc/default/snmpd
cat > $snmpd_conf <<EOF
export MIBS=
SNMPDRUN=yes
SNMPDOPTS='-LS6d -Lf /dev/null -u snmp -g snmp -I -smux -p /var/run/snmpd.pid'
TRAPDRUN=no
TRAPDOPTS='-LS6d -p /var/run/snmptrapd.pid'
SNMPDCOMPAT=yes
EOF

# Set default for rcS to run only one script at a time
rcs_conf=/etc/default/rcS
[ -s $rcs_conf ] && grep -q "^CONCURRENCY=" $rcs_conf
if [ $? != 0 ]; then \
   echo 'CONCURRENCY=none' >> $rcs_conf
else
   grep -q "^CONCURRENCY=none" $rcs_conf
   if [ $? != 0 ]; then \
      sed -i "s/^\(CONCURRENCY\)=.*$/\1=none/" $rcs_conf
   fi
fi

# Disable IPv6
# See: http://www.debian-administration.org/article/409/
dis_ipv6_conf=/etc/network/if-pre-up.d/dis_ipv6
chmod=/bin/chmod
[ "$dis_ipv6" == "1" ] && ([ -s $dis_ipv6_conf ] || cat > $dis_ipv6_conf <<EOF
#!/bin/sh

/sbin/sysctl -w net.ipv6.conf.all.dis_ipv6=1
EOF
([ -w $dis_ipv6_conf ] && [ -x $chmod ]) && $chmod 750 $dis_ipv6_conf)

# Leave a trace that this script has run at least once to completion
mkdir -p $gnarwall
touch $gnarwall_conf

exit 0
```

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

Please give this a try and let us know how it goes.  Also, any feedback on this recipe will be very helpful.


## License

This tutorial and the code listed within is licensed under the [GNU General Public License](http://www.gnu.org/licenses/gpl.html):

```
GnarWall: Logical Firewall and Filtering Bridge
Copyright © 2010-2012 University of Washington

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
