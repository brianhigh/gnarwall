#!/bin/sh

# gnarwall-reset.sh
#
# Remove configuration files so they will be recreated later.

CONFFILE=/etc/gnarwall/configured

cd /etc && rm -f resolv.conf timezone hostname mailname hosts ntp.conf
rm -f /etc/network/if-pre-up.d/disable_ipv6
[ -e $CONFFILE ] && rm -f $CONFFILE
