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
/etc/locale.gen
/etc/network/if-pre-up.d/disable_ipv6
'

for i in `echo $CONF_FILES`; do rm -f $i 2>/dev/null; done
[ -e $GW_CONFIGURED ] && rm -f $GW_CONFIGURED
