#!/bin/sh

# gnarwall-reset.sh
#
# Remove configuration files so they will be recreated later.

GW_CONFIGURED=/etc/gnarwall/configured

CONF_FILES='
/etc/resolv.conf
/etc/timezone
/etc/hostname
/etc/mailname
/etc/hosts
/etc/ntp.conf
/etc/default/locale
/etc/logcheck/ignore.d.server/rsyslog
/etc/modprobe.d/00local.conf
'

for i in `echo $CONF_FILES`; do rm -f $i 2>/dev/null; done
[ -e $GW_CONFIGURED ] && rm -f $GW_CONFIGURED
