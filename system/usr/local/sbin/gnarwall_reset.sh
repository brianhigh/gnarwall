#!/bin/sh

# gnarwall-reset.sh
#
# Remove configuration files so they will be recreated later.

# The semaphore file.  Its presense signifies a configured system.
gnarwall_conf=/etc/gnarwall/configured

# List of filenames (no whitespace or wildcards) to remove.
conf_files='
/etc/resolv.conf
/etc/timezone
/etc/hostname
/etc/mailname
/etc/hosts
/etc/ntp.conf
/etc/default/locale
/etc/locale.gen
/etc/network/if-pre-up.d/disable_ipv6
'

for i in `echo $conf_files`; do rm -f "$i" 2>/dev/null; done
[ -e $gnarwall_conf ] && rm -f $gnarwall_conf
