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
